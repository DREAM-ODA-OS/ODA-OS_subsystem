ODA-OS subsytem
===============

This repository contains the installation and configuration scripts of the
DREAM Tasks 5 ODA-OS sub-system core. 

The repository contains following directories:

-  `scripts/` - installation scripts 
-  `contrib/` - location of the installed SW packages 
-  `ingeng/`  - ingestion engine actions scripts  

NOTE: The repository does not cover the autonomous Cloud-free Coverage
Assembly.

ODA-OS Core Installation
------------------------

In this section the ODA-OS Core installation is described. 

### Prerequisites

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

### Step 1 - Get the Installation Scripts

The installer (i.e., content of this repository) can be obtained
either as on of the [tagged releases](https://github.com/DREAM-ODA-OS/ODA-OS_subsytem/releases)
or by clonning of the repository:

```
$ git clone https://github.com/DREAM-ODA-OS/ODA-OS_subsytem.git
```

### Step 2 - Prepare the installed SW packages

Put the SW packages which i) cannot be downloaded automatically or ii) need to be installed from a newer version not yet available on-line to the `ODA-OS_subsytem/contrib/` directory of the (unpacked or cloned) installer.

### Step 3 - Run the Installation

Execute the installation script with the root's permission:

```
$ sudo ODA-OS_subsytem/scripts/install.sh
```







