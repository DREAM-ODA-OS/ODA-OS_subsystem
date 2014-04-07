ODA-OS subsytem
---------------

This repository contains the installation and configuration scripts of the
DREAM Tasks 5 ODA-OS sub-system core. 

The repository contains following directories:

-  `scripts/` - installation scripts 
-  `contrib/` - location of the installed SW packages 
-  `ingeng/`  - ingestion engine actions scripts  

NOTE: The repository does not cover the autonomous Cloud-free Coverage
Assembly.

### ODA-OS Core Installation

In this section the ODA-OS Core installation is described. 

#### Prerequisites

The installation should be performed on a *clean* (virtual or physical) 
CentOS 6 machine. Although not tested, it is assumed that the installation 
will also work on the RHEL 6 and its other clones (e.g., SL 6).

The installation requires access to the Internet. 

The installation scripts try search for the SW installation packages in the
`contrib/` directory and if not found they try to download the SW packages
form the predefined location. As not all SW packages are available on-line or
or their download requires user's authentication, some of the SW packages might 
need to be downloaded manually and put in the `contrib/` directory beforehand.

Following table shows components which might be needed to be downloaded
manually. 

*SW Component* | *On-line Source* | *Comment*
--- | --- | --- 
ngEO-DM | Spacebel FTP [1] | Required. Downloaded automatically when a valid `.netrc` found in the `contrib/` directory.
local catalogue | *n/a* | Optional. Not yet integrated. 
[1] `ftp://ftp.spacebel.be/Inbox/ASU/MAGELLIUM/DM-Releases/`

#### Step 1 - Get the Installation Scripts

The installer (i.e., content of this repository) can be obtained
either as on of the [tagged releases](https://github.com/DREAM-ODA-OS/ODA-OS_subsytem/releases)
or by clonning of the repository:

```
$ git clone https://github.com/DREAM-ODA-OS/ODA-OS_subsytem.git
```

#### Step 2 - Prepare the installed SW packages

Put the SW packages which i) cannot be downloaded automatically or ii) need to be installed from a newer version not yet available on-line to the `ODA-OS_subsytem/contrib/` directory of the (unpacked or cloned) installer.

#### Step 3 - Run the Installation

Execute the installation script with the root's permission:

```
$ sudo ODA-OS_subsytem/scripts/install.sh
```

The output os the `install.sh` command is automatically saved to a log file
which can be inspected in case of failure.

```
$ more install.log
```

The `install.sh` command executes the individual installation scrips 
located in the `scripts/install.d/` directory: 

```
$ ls ODA-OS_subsytem/scripts/install.d/ 
00_selinux.sh    20_django.sh      30_ngeo_dm_install.sh  40_ngeo_dm_cli-fix.sh
10_rpm_repos.sh  20_gdal.sh        30_odac_install.sh     40_ngeo_dm_config.sh
15_curl.sh       20_postgresql.sh  30_tools_install.sh    45_ie_config.sh
15_pip.sh        30_eoxs_rpm.sh    35_rasdaman_rpm.sh     50_eoxs_instance.sh
20_apache.sh     30_ie_install.sh  40_ie_scripts.sh       50_odac_config.sh
```

By default, all these installation scrips are executed in order given by the 
numerical prefix. However, the `install.sh` command allows execution of 
the expelicitely selected scripts as, e.g., in following command (re-)installing
and (re-)configuring the IngestionEngine:

```
$ sudo ODA-OS_subsytem/scripts/install.sh ODA-OS_subsytem/scripts/install.d/{30_ie_install.sh,45_ie_config.sh}
```

This allows installation and/or update of selected SW packages only. 


#### Step 4 - Hostname Configuration

Some of the services provided by the ODA-OS subsytem require 
configuration of the correct host-name under which the service
will be available. The host-name need not to be always the same 
as the one announced by the operating system during the 
installation. In case, the service host-name (i.e., fully qualified
domain-name or IP adress assigned to the computer) has to be corrected
the following command shall be executed:

```
$ sudo ODA-OS_subsytem/scripts/reset_hostname.sh <host-name>
```

### ODA-OS Core Quick Start 

When the installation has been finished successfully, 
the ODA-OS core shoudl be fully functional. The ODA-Client
(including the Ingestion Admin. Client) is available at:

```
http://<host-name>/oda
```

The EOxServer (core of the ODA-Server) is available at:

```
http://<host-name>/eoxs
```

*More details TBD.*


### ODA-OS Core Administration


#### User names


#### Directories and File Locations 





