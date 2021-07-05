# == Class: oradb::installdb
#
# The databaseType value should contain only one of these choices.
# EE     : Enterprise Edition
# SE     : Standard Edition
# SEONE  : Standard Edition One
#
#
define oradb::installdb(
  $version                 = undef,
  $file                    = undef,
  $databaseType            = 'SE',
  $oraInventoryDir         = undef,
  $oracleBase              = undef,
  $oracleHome              = undef,
  $eeOptionsSelection      = false,
  $eeOptionalComponents    = undef, # 'oracle.rdbms.partitioning:11.2.0.4.0,oracle.oraolap:11.2.0.4.0,oracle.rdbms.dm:11.2.0.4.0,oracle.rdbms.dv:11.2.0.4.0,oracle.rdbms.lbac:11.2.0.4.0,oracle.rdbms.rat:11.2.0.4.0'
  $createUser              = true,
  $bashProfile             = true,
  $user                    = 'oracle',
  $userBaseDir             = '/home',
  $group                   = 'dba',
  $group_install           = 'oinstall',
  $group_oper              = 'oper',
  $downloadDir             = '/install',
  $zipExtract              = true,
  $puppetDownloadMntPoint  = undef,
  $remoteFile              = true,
)
{

  if (!( $version in ['11.2.0.1','12.1.0.1','12.1.0.2','11.2.0.3','11.2.0.4','19.3.0.0'])){
    fail('Unrecognized database install version, use 11.2.0.1|11.2.0.3|11.2.0.4|12.1.0.1|12.1.0.1|19.3.0.0')
  }

  if ( !($::kernel in ['Linux','SunOS'])){
    fail('Unrecognized operating system, please use it on a Linux or SunOS host')
  }

  if ( !($databaseType in ['EE','SE','SEONE','SE2'])){
    fail('Unrecognized database type, please use EE|SE|SEONE|SE2')
  }

  # check if the oracle software already exists
  $found = oracle_exists( $oracleHome )

  if $found == undef {
    $continue = true
  } else {
    if ( $found ) {
      $continue = false
    } else {
      notify {"oradb::installdb ${oracleHome} does not exists":}
      $continue = true
    }
  }

  if ( $continue ) {

    $execPath     = '/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:'

    if $puppetDownloadMntPoint == undef {
      $mountPoint     = 'puppet:///modules/oradb/'
    } else {
      $mountPoint     = $puppetDownloadMntPoint
    }

    if $oraInventoryDir == undef {
      $oraInventory = "${oracleBase}/oraInventory"
    } else {
      $oraInventory = "${oraInventoryDir}/oraInventory"
    }

    oradb::utils::dbstructure{"oracle structure ${version}":
      oracle_base_home_dir => $oracleBase,
      ora_inventory_dir    => $oraInventory,
      os_user              => $user,
      os_group             => $group,
      os_group_install     => $group_install,
      os_group_oper        => $group_oper,
      download_dir         => $downloadDir,
      log_output           => true,
      user_base_dir        => $userBaseDir,
      create_user          => $createUser,
    }

    if ( $zipExtract ) {
      # In $downloadDir, will Puppet extract the ZIP files or is this a pre-extracted directory structure.

      if ( $version in ['11.2.0.1','12.1.0.1','12.1.0.2']) {
        $file1 =  "${file}_1of2.zip"
        $file2 =  "${file}_2of2.zip"
      }

      if ( $version in ['11.2.0.3','11.2.0.4']) {
        $file1 =  "${file}_1of7.zip"
        $file2 =  "${file}_2of7.zip"
      }

      if ( $version == '19.3.0.0' ) {
        $file1 = "${file}.zip"
        $file2 = ""
      }

      if ($remoteFile == true) {
        $source = $downloadDir

        if ($mountPoint =~ /^s3:\/\/.*$/ ) {
          # dowload from S3
          exec { "Download $file1 from $mountPoint":
            command => "/usr/bin/aws s3 cp ${mountPoint}${file1} ${downloadDir}/ && chown ${user}:${group} ${downloadDir}/${file1}",
            creates => "${downloadDir}/${file1}",
            timeout => 0,
            require => Oradb::Utils::Dbstructure["oracle structure ${version}"],
            before => Exec["extract ${downloadDir}/${file1}"],
          }

          if ($file2 != ""){
            exec { "Download $file2 from $mountPoint":
              command => "/usr/bin/aws s3 cp ${mountPoint}${file2} ${downloadDir}/ && chown ${user}:${group} ${downloadDir}/${file2}",
              creates => "${downloadDir}/${file2}",
              timeout => 0,
              require => Oradb::Utils::Dbstructure["oracle structure ${version}"],
              before => Exec["extract ${downloadDir}/${file2}"],
            }
          }
        }
        else {
          # download from puppetmaster
          file { "${downloadDir}/${file1}":
            ensure      => present,
            source      => "${mountPoint}/${file1}",
            mode        => '0775',
            owner       => $user,
            group       => $group,
            require     => Oradb::Utils::Dbstructure["oracle structure ${version}"],
            before      => Exec["extract ${downloadDir}/${file1}"],
          }
          # db file 2 installer zip (if exists)
          if ($file2 != ""){
            file { "${downloadDir}/${file2}":
              ensure      => present,
              source      => "${mountPoint}/${file2}",
              mode        => '0775',
              owner       => $user,
              group       => $group,
              require     => File["${downloadDir}/${file1}"],
              before      => Exec["extract ${downloadDir}/${file2}"]
            }
          }
        }
      } else {
        # remoteFile == false
        $source = $mountPoint
      }

      if ($version in ['11.2.0.1','12.1.0.1','12.1.0.2','11.2.0.3','11.2.0.4']) {
        # 11/12 is extracted to the download dir
        $unzip1 = "unzip -o ${source}/${file1} -d ${downloadDir}/${file}"
      }
      elsif ($version == '19.3.0.0'){
        # 19c is extracted to the final destination
        $unzip1 = "unzip -o ${source}/${file1} -d ${oracleHome}"
      }

      exec { "extract ${downloadDir}/${file1}":
        command     => "${unzip1}",
        timeout     => 0,
        logoutput   => false,
        path        => $execPath,
        user        => $user,
        group       => $group,
        require     => Oradb::Utils::Dbstructure["oracle structure ${version}"],
        before      => Exec["install oracle database ${title}"],
      }
      if ($file2 != ""){
        # only 11/12
        exec { "extract ${downloadDir}/${file2}":
          command     => "unzip -o ${source}/${file2} -d ${downloadDir}/${file}",
          timeout     => 0,
          logoutput   => false,
          path        => $execPath,
          user        => $user,
          group       => $group,
          require     => Exec["extract ${downloadDir}/${file1}"],
          before      => Exec["install oracle database ${title}"],
        }
      }
    }

    oradb::utils::dborainst{"database orainst ${version}":
      ora_inventory_dir => $oraInventory,
      os_group          => $group_install,
    }

    if ! defined(File["${downloadDir}/db_install_${version}.rsp"]) {
      file { "${downloadDir}/db_install_${version}.rsp":
        ensure        => present,
        content       => template("oradb/db_install_${version}.rsp.erb"),
        mode          => '0775',
        owner         => $user,
        group         => $group,
        require       => Oradb::Utils::Dborainst["database orainst ${version}"],
      }
    }

    if ($version in ['11.2.0.1','12.1.0.1','12.1.0.2','11.2.0.3','11.2.0.4']) {
      $run_installer_command = "/bin/sh -c 'unset DISPLAY;${downloadDir}/${file}/database/runInstaller -silent -waitforcompletion -ignoreSysPrereqs -ignorePrereq -responseFile ${downloadDir}/db_install_${version}_${title}.rsp'"
    }
    elsif ($version == '19.3.0.0'){
      $run_installer_command = "/bin/sh -c 'unset DISPLAY;cd ${oracleHome};./runInstaller -silent -waitforcompletion -ignorePrereq -responseFile ${downloadDir}/db_install_${version}_${title}.rsp'"
    }

    exec { "install oracle database ${title}":
      command     => "${run_installer_command}",
      environment => ["USER=${user}","LOGNAME=${user}"],
      cwd         => $oracleBase,
      timeout     => 0,
      returns     => [6,0],
      path        => $execPath,
      user        => $user,
      group       => $group_install,
      logoutput   => true,
      require     => [Oradb::Utils::Dborainst["database orainst ${version}"],
                      File["${downloadDir}/db_install_${version}.rsp"]],
    }

    file { $oracleHome:
      ensure  => directory,
      recurse => false,
      replace => false,
      mode    => '0775',
      owner   => $user,
      group   => $group_install,
      require => Exec["install oracle database ${title}"],
    }

    if ( $bashProfile == true ) {
      if ! defined(File["${userBaseDir}/${user}/.bash_profile"]) {
        file { "${userBaseDir}/${user}/.bash_profile":
          ensure  => present,
          content => template('oradb/bash_profile.erb'),
          mode    => '0775',
          owner   => $user,
          group   => $group,
          require => Oradb::Utils::Dbstructure["oracle structure ${version}"],
        }
      }
    }

    exec { "run root.sh script ${title}":
      command   => "${oracleHome}/root.sh",
      user      => 'root',
      group     => 'root',
      path      => $execPath,
      logoutput => true,
      require   => Exec["install oracle database ${title}"],
    }
  }
}
