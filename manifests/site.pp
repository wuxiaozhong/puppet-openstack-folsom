$public_interface = 'eth0'
$private_interface = 'eth0'
# db
$mysql_root_password = 'root'
$keystone_db_password = 'keystone'
$nova_db_password = 'nova'
$glance_db_password = 'glance'
# keystone
$keystone_admin_token = 'admin_token'

$keystone_admin_email = 'root@localhost'
$keystone_admin_password = 'admin'

$nova_keystone_user_password = 'nova'
$glance_keystone_user_password = 'glance'
# $rabbit_password                 = 'openstack_rabbit_password'
# $rabbit_user                     = 'openstack_rabbit_user'
$fixed_network_range = '10.0.0.0/24'
$floating_network_range = '10.248.34.200/27'

$secret_key = 'secret'
$verbose = true
# by default it does not enable atomatically adding floating IPs
$auto_assign_floating_ip = false

# 机器初始化
# ntp_servers 已知NTP服务器列表，默认为CentOS NTP服务器
# volume_group 卷组名， 默认为nova-volumes
# volume_image 卷文件路径，默认为/data/nova-volumes.img
# volume_size 卷大小，默认为100G
class openstack_init ($ntp_servers = 'UNSET', $volume_group = 'nova-volumes', $volume_image = '/data/nova-volumes.img', $volume_size = '100') 
{
  # 配置主NTP服务器
  class { 'ntp': servers => $ntp_servers }

  # 创建nova-volume
  file { '/root/nova-volume-setup.sh':
    ensure  => present,
    content => template('openstack/nova-volume-setup.sh.erb'),
    group   => root,
    owner   => root,
    mode    => 755
  }

  exec { 'nova-volume-setup':
    command => '/root/nova-volume-setup.sh',
    require => File['/root/nova-volume-setup.sh'],
  }

  # 启动挂载nova-volumes
  file { '/etc/rc.d/init.d/nova-volume-mount':
    ensure  => present,
    content => template('openstack/nova-volume-mount.erb'),
    group   => root,
    owner   => root,
    mode    => 755
  }

  file { ['/etc/rc.d/rc5.d/S96nova-volume-mount', '/etc/rc.d/rc3.d/S96nova-volume-mount']:
    ensure  => link,
    target  => '/etc/rc.d/init.d/nova-volume-mount',
    require => File['/etc/rc.d/init.d/nova-volume-mount'],
  }

  # 配置Iptables
  service { 'iptables':
    ensure => 'stopped',
    enable => false,
  }

  # 配置Openstack YUM源
  file { '/etc/yum.repos.d':
    ensure  => directory,
    path    => '/etc/yum.repos.d',
    recurse => true,
    purge   => true,
  }

  file { "/etc/yum.repos.d/openstack-essex.repo":
    ensure  => present,
    content => template("openstack/openstack-essex.repo.erb"),
    require => File['/etc/yum.repos.d'],
  }
}

# 单节点部署模式-完全安装Openstack
node /allinone.*/ {
  # 初始化机器：
  class { 'openstack_init': }

  # 安装Openstack
  class { 'openstack::all':
    public_address => $ipaddress_eth0,
    public_interface              => $public_interface,
    private_interface             => $private_interface,
    #    mysql_root_password     => $mysql_root_password,
    keystone_db_password          => $keystone_db_password,
    nova_db_password              => $nova_db_password,
    glance_db_password            => $glance_db_password,
    keystone_admin_token          => $keystone_admin_token,
    keystone_admin_email          => $keystone_admin_email,
    keystone_admin_password       => $keystone_admin_password,
    nova_keystone_user_password   => $nova_user_password,
    glance_keystone_user_password => $glance_user_password,
    #    rabbit_password         => $rabbit_password,
    #    rabbit_user             => $rabbit_user,
    libvirt_type   => 'kvm',
    # kvm,qemu
    floating_range => $floating_network_range,
    fixed_range    => $fixed_network_range,
    secret_key     => $secret_key,
    verbose        => $verbose,
    auto_assign_floating_ip       => $auto_assign_floating_ip,
    require        => Class['init'],
  }

  # 生成环境变量文件
  class { 'openstack::component::auth_file':
    keystone_admin_password => $keystone_admin_password,
    keystone_admin_token    => $keystone_admin_token,
    controller_node         => '127.0.0.1',
    require                 => Class['openstack::all'],
  }

}

# 多节点部署模式-安装控制节点
node /controller.*/ {
  # 初始化机器：
  class { 'openstack_init': }

  # 根据当前控制节点eth0网卡的IP地址作为其控制节点IP
  class { 'openstack::controller':
    # nic
    public_interface              => $public_interface,
    private_interface             => $private_interface,
    # ip
    public_address                => $ipaddress_eth0,
    internal_address              => $ipaddress_eth0,
    # db password
    #    mysql_root_password     => $mysql_root_password,
    keystone_db_password          => $keystone_db_password,
    glance_db_password            => $glance_db_password,
    nova_db_password              => $nova_db_password,
    # keystone config
    keystone_admin_token          => $keystone_admin_token,
    keystone_admin_email          => $keystone_admin_email,
    keystone_admin_password       => $keystone_admin_password,
    glance_keystone_user_password => $glance_keystone_user_password,
    nova_keystone_user_password   => $nova_keystone_user_password,
    # network
    network_manager               => 'nova.network.manager.FlatDHCPManager',
    floating_range                => $floating_network_range,
    fixed_range => $fixed_network_range,
    multi_host  => true,
    auto_assign_floating_ip       => $auto_assign_floating_ip,
    # volume
    volume_enabled                => true,
    secret_key  => $secret_key,
    verbose     => $verbose,
    #    rabbit_password         => $rabbit_password,
    #    rabbit_user             => $rabbit_user,
    #    export_resources        => false,
    require     => Class['init'],
  }

  class { 'openstack::component::auth_file':
    keystone_admin_password => $keystone_admin_password,
    keystone_admin_token    => $keystone_admin_token,
    controller_node         => $ipaddress_eth0,
    require                 => Class['openstack::controller'],
  }
}
# 多节点部署模式-安装计算节点
node /computer\d+.*/ {
  $controller_node_public = '10.248.34.18'
  $controller_node_internal = '10.248.34.18'
  $computer_public_address = $ipaddress_eth0
  $computer_internal_address = $ipaddress_eth0

  # 已安装控制节点
  if ($controller_node_public != undef) {
    # 已安装控制节点
    # 配置NTP服务器
    #    exec{'ntpdate':
    #      command =>'echo "*/30 * * * * root ntpdate -s ${controller_node_public}" >> /etc/crontab',
    #      path    => '/bin;/usr/bin',
    #    }
    # 初始化机器：
    class { 'openstack_init':
      ntp_servers => $controller_node_public
    }

    # 安装Openstack计算节点模块
    class { 'openstack::compute':
      public_interface            => $public_interface,
      private_interface           => $private_interface,
      internal_address            => $computer_internal_address,
      nova_db_host                => $controller_node_public,
      nova_db_password            => 'nova',
      nova_keystone_user_password => $nova_keystone_user_password,
      rabbit_host                 => $controller_node_internal,
      glance_api_servers          => "${controller_node_internal}:9292",
      vncproxy_host               => $controller_node_public,
      # network
      network_manager             => 'nova.network.manager.FlatDHCPManager',
      fixed_range                 => $fixed_network_range,
      libvirt_type                => 'kvm',
      # qemu,kvm
      multi_host                  => true,
      #    rabbit_password    => $rabbit_password,
      #    rabbit_user        => $rabbit_user,
      verbose                     => $verbose,
      require                     => Class['init'],
    }
  }
}
