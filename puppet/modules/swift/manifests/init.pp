# == Class: Swift
#
# This Puppet class installs and configures a Swift instance
#
# === Parameters
#
# [*storage_dir*]
#   Path where Swift content will be stored (example: '/var/swift').
#
# [*port*]
#   Port for the proxy server to listen on.
#
# [*key*]
#   Secret key.
#
# [*project*]
#   Project the user belongs to.
#
# [*user*]
#   User.
#
# [*cfg_file*]
#   Swift configuration file. The file will be generated by Puppet.
#
# [*proxy_cfg_file*]
#   Swift proxy server configuration file. The file will be generated by Puppet.
#
# [*account_cfg_file*]
#   Swift account server configuration file. The file will be generated by Puppet.
#
# [*object_cfg_file*]
#   Swift object server configuration file. The file will be generated by Puppet.
#
# [*container_cfg_file*]
#   Swift container server configuration file. The file will be generated by Puppet.
#
class swift (
    $storage_dir,
    $port,
    $key,
    $project,
    $user,
    $cfg_file,
    $proxy_cfg_file,
    $account_cfg_file,
    $object_cfg_file,
    $container_cfg_file,
) {
    include ::apache::mod::proxy
    include ::apache::mod::proxy_http

    require_package('swift')
    require_package('swift-account')
    require_package('swift-container')
    require_package('swift-object')
    require_package('swift-proxy')
    require_package('python-swiftclient')

    user { 'swift':
        ensure     => present,
        managehome => true,
        home       => '/home/swift',
    }

    file { '/etc/swift':
        ensure => 'directory',
        owner  => 'swift',
        group  => 'swift',
    }

    file { '/etc/swift/backups':
        ensure => 'directory',
        owner  => 'swift',
        group  => 'swift',
    }

    file { $storage_dir:
        ensure => 'directory',
        owner  => 'swift',
        group  => 'swift',
    }

    file { "${storage_dir}/1":
        ensure => 'directory',
        owner  => 'swift',
        group  => 'swift',
    }

    file { $cfg_file:
        ensure  => present,
        group   => 'www-data',
        content => template('swift/swift.conf.erb'),
        mode    => '0644',
    }

    file { $proxy_cfg_file:
        ensure  => present,
        group   => 'www-data',
        content => template('swift/proxy-server.conf.erb'),
        mode    => '0644',
    }

    swift::ring { $account_cfg_file:
        ring_type   => 'account',
        cfg_file    => $account_cfg_file,
        storage_dir => $storage_dir,
        ring_port   => 6010,
        require     => Package['swift-account'],
    }

    swift::ring { $object_cfg_file:
        ring_type   => 'object',
        cfg_file    => $object_cfg_file,
        storage_dir => $storage_dir,
        ring_port   => 6020,
        require     => Package['swift-object'],
    }

    swift::ring { $container_cfg_file:
        ring_type   => 'container',
        cfg_file    => $container_cfg_file,
        storage_dir => $storage_dir,
        ring_port   => 6030,
        require     => Package['swift-container'],
    }

    exec { 'swift-init':
        command => 'swift-init start all',
        user    => 'root',
        unless  => "swift -A http://127.0.0.1:${port}/auth/v1.0 -U ${project}:${user} -K ${key} stat -v | grep -Pq 'Auth Token'",
        require => [
            File[$storage_dir],
            File["${storage_dir}/1"],
            File[$cfg_file],
            File[$proxy_cfg_file],
            Ring[$account_cfg_file],
            Ring[$object_cfg_file],
            Ring[$container_cfg_file],
        ],
    }

    file { '/tmp/foo':
        ensure  => present,
        content => 'bar',
        mode    => '0644',
    }

    exec { 'swift-create-public-container':
        command => "swift -A http://127.0.0.1:${port}/auth/v1.0 -U ${project}:${user} -K ${key} upload wiki-local-public /tmp/foo",
        user    => 'root',
        unless  => "curl -s -o /dev/null -w \"%{http_code}\" http://127.0.0.1:${port}/v1/AUTH_${project}/wiki-local-public/tmp/foo | grep -Pq '200'",
        require => [
            Exec['swift-init'],
            File['/tmp/foo'],
        ],
        notify  => Exec['swift-make-container-public'],
    }

    exec { 'swift-make-container-public':
        command     => "swift -A http://127.0.0.1:${port}/auth/v1.0 -U ${project}:${user} -K ${key} post -r '.r:*' wiki-local-public",
        user        => 'root',
        require     => Exec['swift-create-public-container'],
        refreshonly => true,
    }
}
