node /node.renren.com/ {
  include 'apache'
  #mysql
  class { 'mysql::server':
    config_hash => {'bind_address' => '0.0.0.0'}
  }
  ######## BEGIN KEYSTONE ###########
  class { 'keystone::db::mysql':
    user     => 'keystone',
    password => 'keystone',
#    allowed_hosts => ['%', 'localhost'],
  }
  class { 'keystone':
    verbose        => true,
    debug          => true,
    sql_connection => 'mysql://keystone:keystone@127.0.0.1/keystone',
    catalog_type   => 'sql',
    admin_token    => 'admin_token',
  }
  class { 'keystone::roles::admin':
    email    => 'test@puppetlabs.com',
    password => 'admin',
  }
  class { 'keystone::endpoint': }
  ######## BEGIN GLANCE ###########
  class { 'role_glance_mysql': }
  class { 'glance::keystone::auth':
    password => 'glance',
  }
}
class role_glance_mysql {

  class { 'glance::api':
    verbose       => 'True',
    debug         => 'True',
    auth_type         => 'keystone',
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => 'glance',
  }
  class { 'glance::backend::file': }

  class { 'glance::db::mysql':
    password => 'glance',
#    allowed_hosts => ['%', 'localhost'],
   # allowed_hosts = undef,
   # $cluster_id = 'localzone'
  }

  class { 'glance::registry':
    verbose       => 'True',
    debug         => 'True',
    auth_type         => 'keystone',
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => 'glance',
    sql_connection    => 'mysql://glance:glance@127.0.0.1/glance',
  }
  
  ######## BEGIN NOVA ###########
  
  class { 'nova::keystone::auth':
    password => 'nova',
  }
  
  class { 'nova::db::mysql':
    password      => 'nova',
    allowed_hosts => ['%', 'localhost']
  }

  class { 'nova':
    sql_connection     => 'mysql://nova:nova@127.0.0.1/nova',
    image_service      => 'nova.image.glance.GlanceImageService',
    verbose            => true,
  }
  #AMQP  rabbitmq impl
  class { 'nova::rabbitmq':}
  nova_config { 'rpc_backend': value => 'nova.openstack.common.rpc.impl_kombu' }
  #AMQP qpid impl
#  package { 'qpid-cpp-server':
#    ensure => 'present',
#  }
#  exec{'qpid-config':
#    command => '/bin/sed -i -e \'s/auth=.*/auth=no/g\' /etc/qpidd.conf',
#    require => Package['qpid-cpp-server'],
#  }
#  service{'qpidd':
#    ensure => 'running',
#    enable => true,
#    require => Exec['qpid-config'],
#  }
#  nova_config { 'rpc_backend': value => 'nova.openstack.common.rpc.impl_qpid' }
  class { 'nova::api':
    enabled        => true,
    admin_password => 'nova',
  }
  
  class { 'nova::network':
    enabled => true,
    public_interface => 'eth0',
    private_interface => 'eth0',
    network_manager  => 'nova.network.manager.FlatDHCPManager',
    fixed_range => '10.0.0.0/24',
    floating_range => '192.168.222.10/28',
  }
  
  class { 'nova::scheduler':
    enabled => true,
  }

  class { 'nova::objectstore':
    enabled => true
  }
  
  class { 'nova::cert':
    enabled => true
  }
  
  class { 'nova::consoleauth':
    enabled => true
  }
  
  class { 'nova::vncproxy':
      host    => '127.0.0.1',
      enabled => true,
  }
  
  class { 'nova::volume': 
    enabled => true,
  }

  class { 'nova::volume::iscsi': }
  
   class { 'nova::compute':
    enabled => true,
  }

  class { 'nova::compute::libvirt':
    libvirt_type => 'qemu',
  }
  ######## Horizon ########

  class { 'memcached':
    listen_ip => '127.0.0.1',
  }

  class { 'horizon': 
    secret_key => 'admin'
  }


  ######## End Horizon #####
}