# == Define: orawls::fmw
#
# installs FMW software like ADF, FORMS, OIM, WC, WCC, OSB, SOA Suite, B2B, MFT
#
##
define orawls::forms(
  $version              = $::orawls::weblogic::version,        # 1036|1111|1211|1212|1213|1221
  $weblogic_home_dir    = $::orawls::weblogic::weblogic_home_dir,    # /opt/oracle/middleware11gR1/wlserver_103
  $middleware_home_dir  = $::orawls::weblogic::middleware_home_dir,  # /opt/oracle/middleware11gR1
  $oracle_base_home_dir = $::orawls::weblogic::oracle_base_home_dir, # /opt/oracle
  $oracle_home_dir      = undef,                             # /opt/oracle/middleware/Oracle_SOA
  $jdk_home_dir         = $::orawls::weblogic::jdk_home_dir,         # /usr/java/jdk1.7.0_45
  $fmw_file1            = undef,
  $fmw_file2            = undef,
  $fmw_file3            = undef,
  $fmw_file4            = undef,
  $bpm                  = false,
  $healthcare           = false,
  $os_user              = $::orawls::weblogic::os_user,              # oracle
  $os_group             = $::orawls::weblogic::os_group,             # dba
  $download_dir         = $::orawls::weblogic::download_dir,         # /data/install
  $source               = $::orawls::weblogic::source,        # puppet:///modules/orawls/ | /mnt | /vagrant
  $remote_file          = $::orawls::weblogic::remote_file,                              # true|false
  $log_output           = $::orawls::weblogic::log_output,                             # true|false
  $temp_directory       = $::orawls::weblogic::temp_directory,      # /tmp directory
  $ohs_mode             = 'collocated',
  $oracle_inventory_dir = undef,
)
{
  $exec_path    = "${jdk_home_dir}/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:"

  # Set basic umask for execs
  Exec {
    umask => '022',
  }

  if $oracle_inventory_dir == undef {
    $oraInventory = "${oracle_base_home_dir}/oraInventory"
  } else {
    $oraInventory = $oracle_inventory_dir
  }

  case $::kernel {
    'Linux': {
      $oraInstPath = '/etc'
      case $::architecture {
        'i386': {
          $installDir = 'linux'
        }
        default: {
          $installDir = 'linux64'
        }
      }
    }
    'SunOS': {
      $oraInstPath = '/var/opt/oracle'
      case $::architecture {
        'i86pc': {
          $installDir = 'intelsolaris'
        }
        default: {
          $installDir = 'solaris'
        }
      }
    }
    default: {
      fail("Unrecognized operating system ${::kernel}, please use it on a Linux host")
    }

  }
  #Sanitise the resource title so that it can safely be used in filenames and execs etc.
  #After converting all spaces to underscores, remove all non alphanumeric characters (allow hypens and underscores too)
  $convert_spaces_to_underscores = regsubst($title,'\s','_','G')
  $sanitised_title = regsubst ($convert_spaces_to_underscores,'[^a-zA-Z0-9_.-]','','G')


    if $version == 1221 {
      $fmw_silent_response_file = 'orawls/fmw_silent_forms_1221.rsp.erb'
      $binFile1                 = 'fmw_12.2.1.0.0_fr_linux64.bin'
      $createFile1              = "${download_dir}/${sanitised_title}/${binFile1}"
      $type                     = 'bin'
      $total_files              = 1
      $install_type             = 'Forms and Reports Deployment'
      $oracleHome               = "${middleware_home_dir}/forms"
    }
    else {
      $fmw_silent_response_file  = 'orawls/fr_ins_only.rsp.erb'
      $fmw_silent_configure_file = 'orawls/fr_cfg_only.rsp.erb'

      $static_ports_file         = 'orawls/staticports.ini'

      # Add staticports.ini file to tmp directory
      file { '/tmp/staticports.ini':
        ensure => file,
        source => 'puppet:///modules/orawls/staticports.ini',
        mode   => '0775',
      }

      $createFile1 = "${download_dir}/${sanitised_title}/Disk1"

      if $version == 11112 {
        $total_files = 4
        $createFile2 = "${download_dir}/${sanitised_title}/Disk2"
        $createFile3 = "${download_dir}/${sanitised_title}/Disk3"
        $createFile4 = "${download_dir}/${sanitised_title}/Disk4"
      }
      elsif $version == 1112  {
        $total_files = 2
        $createFile2 = "${download_dir}/${sanitised_title}/Disk4"
      }
      else {
        $total_files = 1
      }

      if ($oracle_home_dir == undef) {
        $oracleHome = "${middleware_home_dir}/Oracle_FRM1"
      }
      else {
        $oracleHome = $oracle_home_dir
      }
    }

  # check if the oracle home already exists, only for < 12.1.2, this is for performance reasons
  if $version == 1212 or $version == 1213 or $version == 1221 {
    $continue = true
  } else {
    $found = orawls_oracle_exists($oracleHome)

    if $found == undef {
      $continue = true
    } else {
      if ($found) {
        $continue = false
      } else {
        notify { "orawls::fmw ${sanitised_title} ${oracleHome} does not exists": }
        $continue = true
      }
    }
  }

  if ($continue) {

    if $source == undef {
      $mountPoint = 'puppet:///modules/orawls/'
    } else {
      $mountPoint = $source
    }

    orawls::utils::orainst { "create oraInst for ${name}":
      ora_inventory_dir => $oraInventory,
      os_group          => $os_group,
    }

    file { "${download_dir}/${sanitised_title}_silent.rsp":
      ensure  => present,
      content => template($fmw_silent_response_file),
      mode    => '0775',
      #owner   => $os_user,
      #group   => $os_group,
      backup  => false,
      require => Orawls::Utils::Orainst["create oraInst for ${name}"],
    }

    # Add configure file if it exists
    if($fmw_silent_configure_file) {
      file { "${download_dir}/${sanitised_title}_configure_silent.rsp":
        ensure  => present,
        content => template($fmw_silent_configure_file),
        mode    => '0775',
        #owner   => $os_user,
        #group   => $os_group,
        backup  => false,
        require => Orawls::Utils::Orainst["create oraInst for ${name}"],
      }
    }

    # for performance reasons, download and extract or just extract it
    if $remote_file == true {
      file { "${download_dir}/${fmw_file1}":
        ensure => file,
        source => "${mountPoint}/${fmw_file1}",
        mode   => '0775',
        owner  => $os_user,
        group  => $os_group,
        backup => false,
        before => Exec["extract ${fmw_file1} for ${name}"],
      }
      $disk1_file = "${download_dir}/${fmw_file1}"
    } else {
      $disk1_file = "${source}/${fmw_file1}"
    }

    exec { "extract ${fmw_file1} for ${name}":
      command   => "unzip -o ${disk1_file} -d ${download_dir}/${sanitised_title}",
      creates   => $createFile1,
      path      => $exec_path,
      user      => $os_user,
      group     => $os_group,
      cwd       => $temp_directory,
      logoutput => false,
      require   => Orawls::Utils::Orainst["create oraInst for ${name}"],
    }

    # TODO: we should make a utility function to handle each file rather than copy/pasting and editing
    if ( $total_files > 1 ) {

      # for performance reasons, download and extract or just extract it
      if $remote_file == true {

        file { "${download_dir}/${fmw_file2}":
          ensure  => file,
          source  => "${mountPoint}/${fmw_file2}",
          mode    => '0775',
          owner   => $os_user,
          group   => $os_group,
          backup  => false,
          before  => Exec["extract ${fmw_file2} for ${name}"],
          require => [File["${download_dir}/${fmw_file1}"],
          Exec["extract ${fmw_file1} for ${name}"],],
        }
        $disk2_file = "${download_dir}/${fmw_file2}"
      } else {
        $disk2_file = "${source}/${fmw_file2}"
      }

      exec { "extract ${fmw_file2} for ${name}":
        command   => "unzip -o ${disk2_file} -d ${download_dir}/${sanitised_title}",
        creates   => $createFile2,
        path      => $exec_path,
        user      => $os_user,
        group     => $os_group,
        cwd       => $temp_directory,
        logoutput => false,
        require   => Exec["extract ${fmw_file1} for ${name}"],
        before    => Exec["install ${sanitised_title}"],
      }
    }
    if ( $total_files > 2 ) {

      # for performance reasons, download and extract or just extract it
      if $remote_file == true {

        file { "${download_dir}/${fmw_file3}":
          ensure  => file,
          source  => "${mountPoint}/${fmw_file3}",
          mode    => '0775',
          owner   => $os_user,
          group   => $os_group,
          backup  => false,
          before  => Exec["extract ${fmw_file3}"],
          require => [File["${download_dir}/${fmw_file2}"],
          Exec["extract ${fmw_file2}"],],
        }
        $disk3_file = "${download_dir}/${fmw_file3}"
      } else {
        $disk3_file = "${source}/${fmw_file3}"
      }

      exec { "extract ${fmw_file3} for ${name}":
        command   => "unzip -o ${disk3_file} -d ${download_dir}/${sanitised_title}",
        creates   => $createFile3,
        path      => $exec_path,
        user      => $os_user,
        group     => $os_group,
        cwd       => $temp_directory,
        logoutput => false,
        require   => Exec["extract ${fmw_file2} for ${name}"],
        before    => Exec["install ${sanitised_title}"],
      }
    }
    if ( $total_files > 3 ) {

      # for performance reasons, download and extract or just extract it
      if $remote_file == true {

        file { "${download_dir}/${fmw_file4}":
          ensure  => file,
          source  => "${mountPoint}/${fmw_file4}",
          mode    => '0775',
          owner   => $os_user,
          group   => $os_group,
          backup  => false,
          before  => Exec["extract ${fmw_file4}"],
          require => [File["${download_dir}/${fmw_file3}"],
          Exec["extract ${fmw_file3} for ${name}"],],
        }
        $disk4_file = "${download_dir}/${fmw_file4}"
      } else {
        $disk4_file = "${source}/${fmw_file4}"
      }

      exec { "extract ${fmw_file4} for ${name}":
        command   => "unzip -o ${disk4_file} -d ${download_dir}/${sanitised_title}",
        creates   => $createFile4,
        path      => $exec_path,
        user      => $os_user,
        group     => $os_group,
        cwd       => $temp_directory,
        logoutput => false,
        require   => Exec["extract ${fmw_file3} for ${name}"],
        before    => Exec["install ${sanitised_title}"],
      }
    }

    if $version == 1221 {
      $command = "-silent -responseFile ${download_dir}/${sanitised_title}_silent.rsp"
    }
    else {
      $command = "-silent -response ${download_dir}/${sanitised_title}_silent.rsp -waitforcompletion"
    }

    if $version == 1212 or $version == 1213 or $version == 1221 {
      if $type == 'java' {
        $install = "java -Djava.io.tmpdir=${temp_directory} -jar "
      }
      else {
        $install = ''
      }

      exec { "install ${sanitised_title}":
        command     => "${install}${download_dir}/${sanitised_title}/${binFile1} ${command} -invPtrLoc ${oraInstPath}/oraInst.loc -ignoreSysPrereqs -jreLoc ${jdk_home_dir}",
        environment => "TEMP=${temp_directory}",
        timeout     => 0,
        creates     => $oracleHome,
        cwd         => $temp_directory,
        path        => $exec_path,
        user        => $os_user,
        group       => $os_group,
        logoutput   => $log_output,
        require     => [File["${download_dir}/${sanitised_title}_silent.rsp"],
        Orawls::Utils::Orainst["create oraInst for ${name}"],
        Exec["extract ${fmw_file1} for ${name}"],],
      }
    } else {
      if !defined(File[$oracleHome]) {
        file { $oracleHome:
          ensure => 'directory',
          owner  => $os_user,
          group  => $os_group,
          before => Exec["install ${sanitised_title}"],
        }
      }

      exec { "install ${sanitised_title}":
        command     => "/bin/sh -c 'unset DISPLAY;${download_dir}/${sanitised_title}/Disk1/install/${installDir}/runInstaller ${command} -invPtrLoc ${oraInstPath}/oraInst.loc -ignoreSysPrereqs -jreLoc ${jdk_home_dir} -Djava.io.tmpdir=${temp_directory}'",
        environment => "TEMP=${temp_directory}",
        timeout     => 0,
        creates     => "${oracleHome}/OPatch",
        cwd         => $temp_directory,
        path        => $exec_path,
        user        => $os_user,
        group       => $os_group,
        logoutput   => $log_output,
        umask       => '022',
        require     => [
          File["${download_dir}/${sanitised_title}_silent.rsp"],
          Orawls::Utils::Orainst["create oraInst for ${name}"],
          Exec["extract ${fmw_file1} for ${name}"],
        ],
      }

      if($fmw_silent_configure_file) {
        exec { "config ${sanitised_title}":
          command     => "${oracleHome}/bin/config.sh -silent -waitforcompletion -response ${download_dir}/${sanitised_title}_configure_silent.rsp -jreLoc ${jdk_home_dir} -Djava.io.tmpdir=${temp_directory}",
          environment => "TEMP=${temp_directory}",
          timeout     => 0,
          creates     => "${middleware_home_dir}/instances/frinst_1",
          cwd         => $temp_directory,
          path        => $exec_path,
          user        => $os_user,
          group       => $os_group,
          logoutput   => $log_output,
          umask       => '022',
          require     => [
            File["${download_dir}/${sanitised_title}_configure_silent.rsp"],
            Orawls::Utils::Orainst["create oraInst for ${name}"],
            Exec["extract ${fmw_file1} for ${name}"],
          ],
        }
      }
    }
  }
}