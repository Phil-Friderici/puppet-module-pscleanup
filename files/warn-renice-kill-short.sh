#!/bin/bash
#
######################################################################
# (c) HP - Andras Istvan-Attila
#
# Modified:
#	rsalhe, 041028
#	  Changed $PS_RULES to be a text file. Don't change this script
#	  if you want change the processes to monitor.
#
#	rsalhe, 041206
#	  Creating an empty $WORK_FILE before calling generate_ps_file(),
#	  Otherwise if there are no processes to warn about, the script
#	  complains because the file doesn't exist.
#
#	rsalhe, 051028
#	  Added logging killed processes to $LOG
#
#	rsalhe, 071210
#	  Bugfix: When a process is not associated to a terminal, it
#		  gets a '?' which matches any file in the current
#		  directory with a file name of one character. Now using
#		  an empty work directory.
#
#       qklawit, 080929
#         Changed messages sent to users.
#
#       HP Michael Tosch, 2013-10-31
#       generate_ps_file() now generate_ps_list(), prints to stdout
#       use bash-arithmetics, no external $MYPS, no $WORK_FILE
#       rotate $LOG if too big, compatibility with Solaris
#
#------------------------------------------------------------------------
# Run as root from crontab every 5 minutes.
#
# Edit the file $PRCFILE. Syntax:
#
#   process1:#minutes1
#   process2:#minutes2
#	.
#	.
#
# where "process1" is the name of the process which may run a maximum
# of CPU minutes ("#minutes1"), "process2" is the name of the second
# process etc. One entry per line.
#
# Ex:
#	matlab:45
#	vsim:10
#
# THE PROCESS MUST BE <= 14 CHARACTERS !! A wild card * is allowed.
# THE #MINUTES MUST BE >= 10 MINUTES !!
#
######################################################################

PATH=/usr/xpg4/bin:/bin:/usr/bin:/usr/sbin:/sbin
export PATH

# no wildcard globbing
set -f

basename=${0##*/}

## Configuration BEGIN

BASEDIR=/usr/local/bin
CONFIGDIR=/etc
WRKDIR=/tmp/warn-renice-kill_workdir

# Edit this file to modify which processes to monitor
#
PRCFILE=$CONFIGDIR/warn-renice-kill-short.conf

LOCK_FILE=$WRKDIR/.lock
LOG=$WRKDIR/killed_processes.log

NXSERVER="/usr/NX/bin/nxserver"
NXSESSION="/usr/NX/bin/nxserver --list"
NXMSG="/usr/NX/bin/nxserver --message"

## Configuration END

send_message () {

#	echo Username: "$1"
#	echo PID: "$2"
#	echo TTY: "$3"
#	echo CPU Time: "$4"               # [days-]hh:mm:ss
#	echo Command: "$5"
#	echo "Allowed to run $6 minutes"

# Use of the bash-internal $(( )) instead of the external expr
# $(( )) requires a base 10# prefix, to treat a number with a leading 0 as decimal

  oIFS=$IFS
  IFS=":"
  arr=( $4 )
  IFS=$oIFS
  hour=${arr[0]}
  if [[ "$hour" == *-* ]]
  then
    IFS="-"
    dayhour=( ${arr[0]} )
    IFS=$oIFS
    hour=$(( 10#${dayhour[0]} * 24 + 10#${dayhour[1]} ))
  fi
  minutes=$(( 10#$hour * 60 + 10#${arr[1]} ))

  echo "$minutes, $6"

  [ -z "$minutes" -o -z "$6" ] && return
  if [ $minutes -lt $6 ]
  then
    notified="$WRKDIR/notified_$1_$2_$5"
    begin_warn=$(( 10#$6 - 10 ))
    if [ $minutes -gt $begin_warn -a ! -f "$notified" ]
    then
      >"$notified"
      renice +10 $2 >/dev/null 2>&1
      MESSAGE="You are running the following process pid: $2 $5.\
 This process is probably hanging and will be killed when CPU time exceeds\
 $6 minutes. The process has now been reniced since it is only 10 CPU minutes\
 left to the maximum limit. \
 Please contact your HCR if you have comments regarding this behaviour.\
 "
      if [ "$3" != "\?" ]
      then
        # print to terminal
        echo "$MESSAGE" >"/dev/$3"
      fi
      if [ -x $NXSERVER ]; then
        for i in `$NXSESSION | awk '$2==u {print $4}' u="$1"`; do
          $NXMSG "$i" "$MESSAGE" </dev/null >/dev/null 2>&1
	done
      fi
    fi
  else
    sleep=4 # in case the process needs to be paged in
    for i in 15 12 9
    do
      kill -$i $2 >/dev/null 2>&1 || break # if process is gone
      sleep $sleep
      sleep=1
    done
    rm -f "$notified"

    # Log the killed process
    #
    dstr="`date '+%Y-%m-%d %H:%M'`"
    printf "$1 ($HOSTNAME)\t$5\t$dstr\n" >>$LOG

    MESSAGE="Your process pid: $2 $5 has been killed.\
 There is a $6 CPU minutes maximum for this job until it is considered to be hanging. \
 Please contact your LSM if you have comments regarding this behaviour.\
 "
    if [ "$3" != "\?" ]
    then
      # print to terminal
      echo "$MESSAGE" >"/dev/$3"
    fi
    if [ -x $NXSERVER ]; then
      for i in `$NXSESSION | awk '$2==u {print $4}' u="$1"`; do
        $NXMSG "$i" "$MESSAGE" </dev/null >/dev/null 2>&1
      done
    fi
  fi
}

generate_ps_list () {
  # print result to stdout
  
  ps -e -o user= -o pid= -o tty= -o time= -o comm= |
  while read user pid tty time comm
  do
    while IFS=":" read PS_NAME PS_TIME
    do
       # portability: change /path/to/process to process
       comm=${comm##*/}
       # case understands wildcard globbing (not suppressed by set -f)
       case $comm in
       $PS_NAME) echo "$user $pid $tty $time $comm $PS_TIME";;
       esac
    done < $PRCFILE
  done

}

### Main BEGIN

if [ ! -f $PRCFILE ]
then
  echo "$basename: ERROR: Cannot find configuration file"
  exit 1
fi

mkdir -p $WRKDIR || exit
cd $WRKDIR || exit

# logfile rotation
if [ -f $LOG ] && find $LOG -size +20000 | grep . >/dev/null
then
  cp -p $LOG $LOG.old || exit
  >$LOG
fi

if [ -f $LOCK_FILE ]
then
	read pid < $LOCK_FILE
	[ -z "$pid" ] && exit
	ps -p "$pid" 2>/dev/null | fgrep "$basename" >/dev/null && exit
fi
echo $$ > $LOCK_FILE

generate_ps_list |
while read PS_USERS PS_PID PS_TTY PS_ETIME PS_CMD PS_TIME
do
  echo send_message "$PS_USERS" "$PS_PID" "$PS_TTY" "$PS_ETIME" "$PS_CMD" "$PS_TIME"
  send_message "$PS_USERS" "$PS_PID" "$PS_TTY" "$PS_ETIME" "$PS_CMD" "$PS_TIME"
done

rm -f $LOCK_FILE

exit 0

### Main END
