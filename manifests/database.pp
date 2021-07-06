# == Class: oradb::database
# databaseType  =
define oradb::database(
  $oracleBase               = undef,
  $oracleHome               = undef,
  $version                  = '11.2',
  $user                     = 'oracle',
  $group                    = 'dba',
  $downloadDir              = '/install',
  $action                   = 'create',
  $dbName                   = 'orcl',
  $dbDomain                 = undef,
  $sysPassword              = 'Welcome01',
  $systemPassword           = 'Welcome01',
  $dataFileDestination      = undef,
  $recoveryAreaDestination  = undef,
  $characterSet             = 'AL32UTF8',
  $nationalCharacterSet     = 'UTF8',
  $initParams               = undef,
  $sampleSchema             = TRUE,
  $memoryPercentage         = '40',
  $memoryTotal              = '800',
  $databaseType             = 'MULTIPURPOSE',  # MULTIPURPOSE|DATA_WAREHOUSING|OLTP
  $emConfiguration          = 'NONE',  # CENTRAL|LOCAL|ALL|NONE
  $storageType              = 'FS', #FS|CFS|ASM
  $asmSnmpPassword          = 'Welcome01',
  $dbSnmpPassword           = 'Welcome01',
  $asmDiskgroup             = 'DATA',
  $recoveryDiskgroup        = undef,
){
  if (!( $version in ['11.2','12.1','19.3'])) {
    fail('Unrecognized version')
  }

  if $action == 'create' {
    # used in the DBCA template for 11/12
    $operationType = 'createDatabase'
  } else {
    fail('Unsupported database action')
  }

  if (!( $databaseType in ['MULTIPURPOSE','DATA_WAREHOUSING','OLTP'])) {
    fail('Unrecognized databaseType')
  }

  if (!( $emConfiguration in ['NONE','CENTRAL','LOCAL','ALL'])) {
    fail('Unrecognized emConfiguration')
  }

  if (!( $storageType in ['FS','CFS','ASM'])) {
    fail('Unrecognized storageType')
  }

  if ($::kernel != 'Linux') {
    fail('Unsupported operating system')
  }

  $execPath    = "${oracleHome}/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:"
  $path        = $downloadDir

  Exec {
    path        => $execPath,
    user        => $user,
    group       => $group,
    environment => ["USER=${user}",],
    logoutput   => true,
  }

  File {
    ensure     => present,
    mode       => '0775',
    owner      => $user,
    group      => $group,
  }

  $sanitized_title = regsubst($title, '[^a-zA-Z0-9.-]', '_', 'G')
  $filename = "${path}/database_${sanitized_title}.rsp"

  if $dbDomain {
      $globalDbName = "${dbName}.${dbDomain}"
  } else {
      $globalDbName = $dbName
  }

  if ! defined(File[$filename]) {
    file { $filename:
      ensure       => present,
      content      => template("oradb/dbca_${version}.rsp.erb"),
    }
  }

  if ($version == '19.3'){
    $dbca_operation='-createDatabase'
  }
  else {
    $dbca_operation=''
  }

  exec { "install oracle database ${title}":
    command      => "dbca -silent ${dbca_operation} -responseFile ${filename}",
    require      => File[$filename],
    creates      => "${oracleBase}/admin/${dbName}",
    timeout      => 0,
  }
}
