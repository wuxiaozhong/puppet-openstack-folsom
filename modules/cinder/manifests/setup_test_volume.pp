class cinder::setup_test_volume(
  $volume_name     = 'cinder-volumes',
  $size            = '4G',
  $loopback_device = '/dev/loop2'
) {

  Exec {
    cwd => '/tmp/',
  }

  exec { "/bin/dd if=/dev/zero of=${volume_name} bs=1 count=0 seek=${size}":
    unless => "/sbin/vgdisplay ${volume_name}"
  } ~>

  exec { "/sbin/losetup ${loopback_device} ${volume_name}":
    refreshonly => true,
  } ~>

  exec { "/sbin/pvcreate ${loopback_device}":
    refreshonly => true,
  } ~>

  exec { "/sbin/vgcreate ${volume_name} ${loopback_device}":
    refreshonly => true,
  }

}

