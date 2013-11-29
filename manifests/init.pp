# == Class: pscleanup
#
# Manage pscleanup cron job
#
class pscleanup(
  $cron_ensure  = 'present',
  $cron_command = '[ -x /usr/local/bin/warn-renice-kill-short.sh ] && /usr/local/bin/warn-renice-kill-short.sh >/dev/null 2>&1',
  $cron_user    = 'root',
  $cron_target  = 'root',
  $cron_hour    = '*',
  $cron_minute  = '*/10',
  $pslist       = undef,
) {

  if $pslist == undef {
    fail( "pslist can not be undef, please specify the command" )
  }

  cron { 'warn-renice-kill':
    ensure  => $cron_ensure,
    command => $cron_command,
    user    => $cron_user,
    target  => $cron_target,
    hour    => $cron_hour,
    minute  => $cron_minute,
  }
  file { '/usr/local/bin/warn-renice-kill-short.sh' :
    ensure  => file,
    mode    => '0744',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/pscleanup/warn-renice-kill-short.sh',
  }
  file { '/usr/local/bin/myps.pl' :
    ensure => file,
    mode   => '0744',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/pscleanup/myps.pl',
  }
  file { '/etc/warn-renice-kill-short.conf' :
    ensure => file,
    mode   => '0444',
    owner  => 'root',
    group  => 'root',
    content => template( 'pscleanup/warn-renice-kill-short.conf.erb' ),
  }
}
