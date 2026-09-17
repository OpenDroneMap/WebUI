<img alt="OpenDroneMap WebUI" src="https://github.com/user-attachments/assets/7b0d82b9-2041-409e-bd95-06cbc024ffc0" width=480>

> **📢 OpenDroneMap has officially decoupled from WebODM!** [Read the announcement](https://opendronemap.org/blog/announcement/)

A user-friendly, commercial grade software for drone image processing. Generate georeferenced maps, point clouds, elevation models and textured 3D models from aerial images. It supports multiple engines for processing, currently [ODM](https://github.com/OpenDroneMap/OpenDroneMap/ODM) and [MicMac](https://github.com/OpenDroneMap/NodeMICMAC/).

![Screenshot of WebUI](https://github.com/user-attachments/assets/5bc10862-ebf9-453a-9857-3c6a1cfec110)

- [Getting Started](#getting-started)
   * [Recommended Machine Specs](#recommended-machine-specs)
   * [Manual installation (Docker)](#manual-installation-docker)
      + [Requirements](#requirements)
      + [Installation with Docker](#installation-with-docker)
      + [Manage Processing Nodes](#manage-processing-nodes)
      + [Enable MicMac](#enable-micmac)
      + [Enable SSL](#enable-ssl)
      + [Enable IPv6](#enable-ipv6)
      + [Where Are My Files Stored?](#where-are-my-files-stored)
      + [Common Troubleshooting](#common-troubleshooting)
      + [Backup and Restore](#backup-and-restore)
      + [Reset Password](#reset-password)
      + [Manage Plugins](#manage-plugins)
      + [Update](#update)
   * [Run the docker version as a Linux Service](#run-the-docker-version-as-a-linux-service)
   * [Run it natively](#run-it-natively)
   * [Run it on the cloud (Google Compute, Amazon AWS)](#run-it-on-the-cloud-google-compute-amazon-aws)
- [Customizing and Extending](#customizing-and-extending)
- [API Docs](#api-docs)
- [Roadmap](#roadmap)
- [Getting Help](#getting-help)
- [Support the Project](#support-the-project)
- [Translations](#translations)
- [Become a Contributor](#become-a-contributor)
- [Architecture Overview](#architecture-overview)
- [License](#license)
- [Trademark](#trademark)
 
 * [Download](https://opendronemap.org/download)
 * [Documentation](https://docs.opendronemap.org/)
 * [Hardware Requirements](https://docs.opendronemap.org/installation/#hardware-requirements)
 * [Support the Project](https://docs.opendronemap.org/support-the-project/)

# Getting Started

Windows and macOS users can purchase an automated [installer](https://www.opendronemap.org/webodm/download#installer), which makes the installation process easier.

## Recommended Machine Specs

To run a standalone installation of WebUI (the user interface), including the processing component (NodeODM), we recommend at a minimum:

* 100 GB free disk space
* 16 GB RAM

Don't expect to process more than a few hundred images with these specifications. To process larger datasets, add more RAM linearly to the number of images you want to process. A CPU with more cores will speed up processing, but can increase memory usage. GPU acceleration is also supported on Linux and WSL. To make use of your CUDA-compatible graphics card, make sure to pass `--gpu` when starting WebUI. You need the nvidia-docker installed in this case, see https://github.com/NVIDIA/nvidia-docker and https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#docker for information on docker/NVIDIA setup.

WebUI runs best on Linux, but works well on Windows and Mac too. If you are technically inclined, you can get WebUI to run natively on all three platforms.

WebUI by itself is just a user interface (see [below](#odm-nodeodm-webodm-what)) and does not require many resources. WebUI can be loaded on a machine with just 1 or 2 GB of RAM and work fine without NodeODM. You can then use a processing service such as the [lightning network](https://webodm.net) or run NodeODM on a separate, more powerful machine.

## Manual installation (Docker)
To install WebUI manually on your machine with docker:

### Requirements
  - [Git](https://git-scm.com/downloads)
  - [Docker](https://www.docker.com/)

* Windows users should install [Docker Desktop](https://hub.docker.com/editions/community/docker-ce-desktop-windows) and :
    1. make sure Linux containers are enabled (Switch to Linux Containers...)

    2.  give Docker enough CPUs (default 2) and RAM (>4Gb, 16Gb better but leave some for Windows) by going to Settings -- Advanced

    3.  select where on your hard drive you want virtual hard drives to reside (Settings -- Advanced -- Images & Volumes).
    
    4.  If you want to run the processing component (NodeODM) with GPU acceleration, install [WSL](https://learn.microsoft.com/windows/wsl/) and [set up GPU acceleration](https://learn.microsoft.com/windows/wsl/tutorials/gpu-compute). It's supported on Windows 11 or Windows 10, version 21H2 or higher.

### Installation with Docker
* From the Docker Quickstart Terminal or Git Bash (Windows), or from the command line (Mac / Linux / WSL), type:
```bash
git clone https://github.com/OpenDroneMap/WebUI --config core.autocrlf=input --depth 1
cd WebUI
./webodm.sh start
```
* If you face any issues at the last step on Linux, make sure your user is part of the docker group:
```bash
sudo usermod -aG docker $USER
exit
(restart shell by logging out and then back-in)
./webodm.sh start
```
* Open a Web Browser to `http://localhost:8000` (unless you are on Windows using Docker Toolbox, see below)

Docker Toolbox users need to find the IP of their docker machine by running this command from the Docker Quickstart Terminal:

```bash
docker-machine ip
192.168.1.100 (your output will be different)
```

The address to connect to would then be: `http://192.168.1.100:8000`.

To stop WebUI press CTRL+C or run:

```
./webodm.sh stop
```

To update WebUI to the latest version use:

```bash
./webodm.sh update
```

### Manage Processing Nodes

WebUI can be linked to one or more processing nodes that speak the [NodeODM API](https://github.com/OpenDroneMap/NodeODM/blob/master/docs/index.adoc), such as [NodeODM](https://github.com/OpenDroneMap/NodeODM), [NodeMICMAC](https://github.com/OpenDroneMap/NodeMICMAC/) or [ClusterODM](https://github.com/OpenDroneMap/ClusterODM). The default configuration includes a "node-odm-1" processing node which runs on the same machine as WebUI, just to help you get started. As you become more familiar with WebUI, you might want to install processing nodes on separate machines.

Adding more processing nodes will allow you to run multiple jobs in parallel.

You can also setup a [ClusterODM](https://github.com/OpenDroneMap/ClusterODM) node to run a single task across multiple machines with [distributed split-merge](https://docs.opendronemap.org/large/?highlight=distributed#getting-started-with-distributed-split-merge) and process dozen of thousands of images more quickly, with less memory.

If you don't need the default "node-odm-1" node, simply pass `--default-nodes 0` flag when starting WebUI:

`./webodm.sh restart --default-nodes 0`.

Then from the web interface simply manually remove the "node-odm-1" node.

### Enable MicMac

WebUI can use [MicMac](https://github.com/OpenDroneMap/micmac) as a processing engine via [NodeMICMAC](https://github.com/OpenDroneMap/NodeMICMAC/). To add MicMac, simply run:

`./webodm.sh restart --with-micmac`

This will create a "node-micmac-1" processing node on the same machine running WebUI. Please note that NodeMICMAC is in active development and is currently experimental. If you find issues, please [report them](https://github.com/OpenDroneMap/NodeMICMAC/issues) on the NodeMICMAC repository.

### Enable SSL

WebUI has the ability to automatically request and install a SSL certificate via [Let’s Encrypt](https://letsencrypt.org/), or you can manually specify your own key/certificate pair.

 - Setup your DNS record (webodm.myorg.com --> IP of server).
 - Make sure port 80 and 443 are open.
 - Run the following:

```bash
./webodm.sh restart --ssl --hostname webodm.myorg.com
```

That's it! The certificate will automatically renew when needed.

If you want to specify your own key/certificate pair, simply pass the `--ssl-key` and `--ssl-cert` option to `./webodm.sh`. See `./webodm.sh --help` for more information.

Note! You cannot pass an IP address to the hostname parameter! You need a DNS record setup.

### Enable IPv6

Your installation must first have a public IPv6 address.
To enable IPv6 on your installation, you need to activate IPv6 in Docker by adding the following to a file located at /etc/docker/daemon.json:
```bash
{
  "ipv6": true,
  "fixed-cidr-v6": "fdb4:4d19:7eb5::/64"
}
```
Restart Docker:
`systemctl restart docker`

To add IPv6, simply run:

`./webodm.sh restart --ipv6`

Note: When using `--ssl` mode, you cannot pass an IP address to the hostname parameter; you must set up a DNS AAAA record. Without `--ssl` mode enabled, access the site at (e.g., http://[2001:0db8:3c4d:0015::1]:8000). The brackets around the IPv6 address are essential!
You can add a new NodeODM node in WebUI by specifying an IPv6 address. Don’t forget to include brackets around the address! e.g., [2001:0db8:fd8a:ae80::1]

### Where Are My Files Stored?

When using Docker, all processing results are stored in a docker volume and are not available on the host filesystem. There are two specific docker volumes of interest:
1. Media (called webodm_appmedia): This is where all files related to a project and task are stored.
2. Postgres DB (called webodm_dbdata): This is what Postgres database uses to store its data.

For more information on how these two volumes are used and in which containers, please refer to the [docker-compose.yml](docker-compose.yml) file.

For various reasons such as ease of backup/restore, if you want to store your files on the host filesystem instead of a docker volume, you need to pass a path via the `--media-dir` and/or the `--db-dir` options:

```bash
./webodm.sh restart --media-dir /home/user/webodm_data --db-dir /home/user/webodm_db
```

Note that existing task results will not be available after the change. Refer to the [Migrate Data Volumes](https://docs.docker.com/engine/tutorials/dockervolumes/#backup-restore-or-migrate-data-volumes) section of the Docker documentation for information on migrating existing task results.

### Common Troubleshooting

Symptoms | Possible Solutions
--------- | ------------------
Run out of memory |  Make sure that your Docker environment has enough RAM allocated: [MacOS Instructions](http://stackoverflow.com/a/39720010), [Windows Instructions](https://docs.docker.com/desktop/settings/windows/#advanced)
While starting WebUI you get: `'WaitNamedPipe','The system cannot find the file specified.'` | 1. Make sure you have enabled VT-x virtualization in the BIOS.<br/>2. Try to downgrade your version of Python to 2.7
On Windows, docker-compose fails with `Failed to execute the script docker-compose` | Make sure you have enabled VT-x virtualization in the BIOS
Cannot access WebUI using Microsoft Edge on Windows 10 | Try to tweak your internet properties according to [these instructions](http://www.hanselman.com/blog/FixedMicrosoftEdgeCantSeeOrOpenVirtualBoxhostedLocalWebSites.aspx)
Getting a `No space left on device` error, but hard drive has enough space left | Docker on Windows by default will allocate only 20GB of space to the default docker-machine. You need to increase that amount. See [this link](http://support.divio.com/local-development/docker/managing-disk-space-in-your-docker-vm) and [this link](https://www.howtogeek.com/124622/how-to-enlarge-a-virtual-machines-disk-in-virtualbox-or-vmware/)
Cannot start WebUI via `./webodm.sh start`, error messages are different at each retry | You could be running out of memory. Make sure you have enough RAM available. 2GB should be the recommended minimum, unless you know what you are doing
While running WebUI with Docker Toolbox (VirtualBox) you cannot access WebUI from another computer in the same network. | As Administrator, run `cmd.exe` and then type `"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm "default" natpf1 "rule-name,tcp,,8000,,8000"`
On Windows, the storage space shown on the WebUI diagnostic page is not the same as what is actually set in Docker's settings. | From Hyper-V Manager, right-click “DockerDesktopVM”, go to Edit Disk, then choose to expand the disk and match the maximum size to the settings specified in the docker settings. Upon making the changes, restart docker.
On Linux or WSL, Warning: `GPU use was requested, but no GPU has been found` | Run `nvidia-smi` (natively) or `docker run --rm --gpus all nvidia/cuda:11.2.2-devel-ubuntu20.04 nvidia-smi` (docker) to check with [NVIDIA driver](https://www.nvidia.com/drivers/unix/) and [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

### Backup and Restore

If you want to move WebUI to another system, you just need to transfer the docker volumes (unless you are storing your files on the file system).

On the old system:

```bash
mkdir -v backup
docker run --rm --volume webodm_dbdata:/temp --volume `pwd`/backup:/backup ubuntu tar cvf /backup/dbdata.tar /temp
docker run --rm --volume webodm_appmedia:/temp --volume `pwd`/backup:/backup ubuntu tar cvf /backup/appmedia.tar /temp
```

Your backup files will be stored in the newly created `backup` directory. Transfer the `backup` directory to the new system, then on the new system:

```bash
ls backup # --> appmedia.tar  dbdata.tar
./webodm.sh down # Make sure WebUI is down
docker run --rm --volume webodm_dbdata:/temp --volume `pwd`/backup:/backup ubuntu bash -c "rm -fr /temp/* && tar xvf /backup/dbdata.tar"
docker run --rm --volume webodm_appmedia:/temp --volume `pwd`/backup:/backup ubuntu bash -c "rm -fr /temp/* && tar xvf /backup/appmedia.tar"
./webodm.sh start
```
In case when recovery .tar is missed, or corrupted you can conduct [Hard Recovery](/contrib/Hard_Recovery_Guide.md)

### Reset Password

If you forgot the password you picked the first time you logged into WebUI, to reset it just type:

```bash
./webodm.sh start && ./webodm.sh resetadminpassword newpass
```

The password will be reset to `newpass`. The command will also tell you what username you chose.

### Manage Plugins

Plugins can be enabled and disabled from the user interface. Simply go to Administration -- Plugins.

### Update

If you use docker, updating is as simple as running:

```bash
./webodm.sh update
```

# Customizing and Extending

Small customizations such as changing the application colors, name, logo, or adding custom CSS/HTML/Javascript can be performed directly from the Customize -- Brand/Theme panels within WebUI. No need to fork or change the code.

More advanced customizations can be achieved by writing [plugins](https://github.com/OpenDroneMap/WebUI/tree/master/coreplugins). This is the preferred way to add new functionality to WebUI since it requires less effort than maintaining a separate fork. The plugin system features server-side [signals](https://github.com/OpenDroneMap/WebUI/blob/master/app/plugins/signals.py) that can be used to be notified of various events, a ES6/React build system, a dynamic [client-side API](https://github.com/OpenDroneMap/WebUI/tree/master/app/static/app/js/classes/plugins) for adding elements to the UI, a built-in data store, an async task runner, a GRASS engine, hooks to add menu items and functions to rapidly inject CSS, Javascript and Django views.

For plugins, the best source of documentation currently is to look at existing [code](https://github.com/OpenDroneMap/WebUI/tree/master/coreplugins). If a particular hook / entrypoint for your plugin does not yet exist, [request it](https://github.com/OpenDroneMap/WebUI/issues). We are adding hooks and entrypoints as we go.

To create a plugin simply copy the `plugins/test` plugin into a new directory (for example, `plugins/myplugin`), then modify `manifest.json`, `plugin.py` and issue a `./webodm.sh restart`.

# API Docs

See the [API documentation page](http://docs.webodm.org).

# Roadmap

We follow a bottom-up approach to decide what new features are added to WebUI. User feedback guides us in the decision making process and we collect such feedback via [improvement requests](https://github.com/OpenDroneMap/WebUI/issues?q=is%3Aopen+is%3Aissue+label%3Aimprovements).

Don't see a feature that you want? [Open a feature request](https://github.com/OpenDroneMap/WebUI/issues) or [help us build it](/CONTRIBUTING.md).

Sometimes we also prioritize work that has received financial backing. If your organization is in the position to financially support the development of a particular feature, [get in touch](https://community.opendronemap.org) and we'll make it happen.

# Getting Help

We have several channels of communication for people to ask questions and to get involved with the community:

 - [OpenDroneMap Community Forum](http://community.opendronemap.org/c/webodm)
 - [Report Issues](https://github.com/OpenDroneMap/WebUI/issues)


# Support the Project

There are many ways to contribute back to the project:

 - Help us test new and existing features and report [bugs](https://www.github.com/OpenDroneMap/WebUI/issues) and [feedback](http://community.opendronemap.org/c/webodm).
 - [Share](http://community.opendronemap.org/c/datasets) your aerial datasets.
 - Help answer questions on the community [forum](http://community.opendronemap.org/c/desktop).
 - ⭐️ us on GitHub.
 - Help us classify [point cloud datasets](https://github.com/OpenDroneMap/ODMSemantic3D).
 - Spread the word about WebUI and OpenDroneMap on social media.
 - You can [pledge funds](https://fund.webodm.org) for getting new features built and bug fixed.
 - Become a contributor 🤘

# Architecture Overview

The [OpenDroneMap project](https://github.com/OpenDroneMap/) is composed of several components.

- [ODM](https://github.com/OpenDroneMap/ODM) is a command line toolkit that processes aerial images. Users comfortable with the command line are probably OK using this component alone.
- [NodeODM](https://github.com/OpenDroneMap/NodeODM) is a lightweight interface and API (Application Program Interface) built directly on top of [ODM](https://github.com/OpenDroneMap/ODM). Users not comfortable with the command line can use this interface to process aerial images and developers can use the API to build applications. Features such as user authentication, map displays, etc. are not provided.
- [WebUI](https://github.com/OpenDroneMap/WebUI) adds more features such as user authentication, map displays, 3D displays, a higher level API and the ability to orchestrate multiple processing nodes (run jobs in parallel). Processing nodes are simply servers running [NodeODM](https://github.com/OpenDroneMap/NodeODM).

WebUI is built with scalability and performance in mind. While the default setup places all databases and applications on the same machine, users can separate its components for increased performance (ex. place a Celery worker on a separate machine for running background tasks).

A few things to note:
 * We use Celery workers to do background tasks such as resizing images and processing task results, but we use an ad-hoc scheduling mechanism to communicate with NodeODM (which processes the orthophotos, 3D models, etc.). The choice to use two separate systems for task scheduling is due to the flexibility that an ad-hoc mechanism gives us for certain operations (capture task output, persistent data and ability to restart tasks mid-way, communication via REST calls, etc.).
 * If loaded on multiple machines, Celery workers should all share their `app/media` directory with the Django application (via network shares). You can manage workers via `./worker.sh`
 
# License

OpenDroneMap WebUI is licensed under the terms of the [GNU Affero General Public License v3.0](https://github.com/OpenDroneMap/WebUI/blob/master/LICENSE.md).

# Trademark

See [Trademark Guidelines](https://github.com/OpenDroneMap/documents/blob/main/TRADEMARK.md)
