ODA-OS subsystem
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
ngEO-DM | *n/a* | Required.
DQ subsystem | *n/a* | Optional.
eXcat catalogue | *n/a* | Optional.
S2-preprocessor | *n/a* | Optional.

#### Step 1 - Get the Installation Scripts

The installer (i.e., content of this repository) can be obtained
either as on of the [tagged releases](https://github.com/DREAM-ODA-OS/ODA-OS_subsystem/releases)
or by clonning of the repository:

```
$ git clone https://github.com/DREAM-ODA-OS/ODA-OS_subsystem.git
```

#### Step 2 - Prepare the installed SW packages

Put the SW packages which i) cannot be downloaded automatically or ii) need to
be installed from a newer version not yet available on-line to the
`ODA-OS_subsystem/contrib/` directory of the (unpacked or cloned) installer.

#### Step 3 - Run the Installation

Execute the installation script with the root's permission:

```
$ sudo ODA-OS_subsystem/scripts/install.sh
```

The output os the `install.sh` command is automatically saved to a log file
which can be inspected in case of failure.

```
$ more install.log
```

The `install.sh` command executes the individual installation scrips 
located in the `scripts/install.d/` directory: 

```
$ ls ODA-OS_subsystem/scripts/install.d/ 
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
$ sudo ODA-OS_subsystem/scripts/install.sh ODA-OS_subsystem/scripts/install.d/{30_ie_install.sh,45_ie_config.sh}
```

This allows installation and/or update of selected SW packages only. 

The optional components are excluded from the automatic installation.
The optional installers are located in the `scripts/optional.d/` directory:

```
$ ls ODA-OS_subsystem/scripts/optional.d/
21_tomcat7.sh  30_excat2_install.sh  35_data_quality_install.sh  60_data_quality_config.sh
```
These scritps have to be executed manually, e.g:

```
$ sudo ODA-OS_subsystem/scripts/install.sh ODA-OS_subsystem/scripts/install.d/{21_tomcat7.sh,30_excat2_install.sh}
```

#### Step 4 - Hostname Configuration

Some of the services provided by the ODA-OS subsystem require configuration of
the correct host-name under which the service will be available. The host-name
need not to be always the same as the one announced by the operating system
during the installation. In case, the service host-name (i.e., fully qualified
domain-name or IP adress assigned to the computer) has to be corrected the
following command shall be executed:

```
$ sudo ODA-OS_subsystem/scripts/reset_hostname.sh <host-name>
```

### ODA-OS Core Quick Start 

When the installation has been finished successfully, the ODA-OS core shoudl be
fully functional. The ODA-Client (including the Ingestion Admin. Client) is
available at:

```
http://<host-name>/oda
```

The EOxServer (core of the ODA-Server) is available at:

```
http://<host-name>/eoxs
```

*More details TBD.*


### ODA-OS Core Administration

This section provides brief introduction to the administration ODA-OS Core and
to the detail of the configuration. The text focuses on the scecific aspects of
the ODA-Core installation and it does not intend to replace the documentation
of the idividual components.

#### System Service

The ODA-OS utilizes following system service (administred via the `chkconfig`
and `service` command [4])

-  `ngeo-dm` - The ngEO Download Manager (local deamon, not exposed to the external world)
-  `ingeng`  - The Ingestion Engine (autonomous daemon accesible via Apache reverse proxy)  
-  `httpd`   - The Apche web server - the web interface. 
-  `postgresql` - The PostgreSQL database.
-  `tomcat6` - Tomcat 6 (Rasdaman Petascope).
-  `rasdaman` - Rasdaman (raster-DB backend).
-  `tomcat` - (optional) Tomcat 7 (eXcat catalogue).
-  `tomcat-dq` - (optional) Tomcat 7 (Data Quality proxy).

*Additional services may still be added.*

[4] https://access.redhat.com/site/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Deployment_Guide/ch-Services_and_Daemons.html


#### Directories and File Locations 

The ODA-OS is structure in the following subdirectories:
-  `/srv/eodata/` - data storage (anticipated to be mounted from a separate storage volume). 
-  `/srv/odaos/` - location of the installed SW and its configuration.
-  `/var/log/odaos` - location of the logfiles of the SW components. 
-  `/srv/pgdata/` - PosgreSQL DB files (including Rasdaman raster-DB) 

#### User Identities 

The installed SW components and their configuration is owned by `odaos`
admnistrator, a system user with no password assigned. Any modification of the
configuration requires `odaos` user identity. 

The actual service are operated having `apache` system user's identity and all
the files created or modified by the services are either owned directly by the
`apache` user or they belong to `apache` user group with write permission
granted.

The SW installed from the RPM packages is owned by the `root` and they are not
supposed to be modified.

*More details TBD*

