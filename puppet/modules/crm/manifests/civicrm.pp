# == Class: crm::civicrm
#
# CiviCRM with Wikimedia customizations
#
class crm::civicrm {
    $install_script = "${::crm::dir}/sites/default/civicrm-install.php"

    mysql::db { 'civicrm':
        dbname => $crm::civicrm_db,
    }

    exec { 'civicrm setup':
        command => "php ${install_script}",
        # FIXME: get yr own db user
        unless  => "mysql -u ${::crm::db_user} -p${::crm::db_pass} ${::crm::civicrm_db} -e 'select count(*) from civicrm_domain' > /dev/null",
        require => [
            File[$install_script],
            Mysql::Db['civicrm'],
            Exec['drupal db install'],
        ],
    }

    file { $install_script:
        content => template('crm/civicrm-install.php.erb'),
        mode    => '0640',
        require => Git::Clone[$::crm::repo],
    }
}
