# iocage-plugin-mkv

Artifact file(s) for creating a jail for processing mkv files.

### Prerequisites

#### Enable Linux compatibility
1. Add a FreeNAS `rc.conf` Tunable (_System -> Tunables -> Add_):

   field | value
   ----- | -----
   Variable | `linux_enable`
   Value | `YES`
   Type | `rc.conf`
   Enabled | `checked`

2. Patch `iocage` to allow multiple `devfs` arguments:
```sh
cat << "PATCH" | patch /usr/local/lib/python3.8/site-packages/iocage_lib/ioc_common.py
--- ioc_common.py	2020-12-05 20:48:33.751671703 -0800
+++ ioc_common.py	2020-12-05 20:49:21.982174538 -0800
@@ -820,7 +820,7 @@
         path = ['add', 'path', path]
 
         if mode is not None:
-            path += [mode]
+            path += mode.strip().split()
         else:
             path += ['unhide']
 
PATCH
```

3. Reboot

4. If you skipped rebooting, load linux64 kernel module via Shell:  
   `kldload linux64`

5. If using host as a jumpbox to jail, allow ssh TCP forwarding by editing FreeNAS' SSH service (_Services -> SSH -> Configure_)  
   `Allow TCP Port Forwarding: Checked`


### Install
1. Download plugin manifest:  
   `wget https://raw.githubusercontent.com/dacto/iocage-plugin-mkv/master/mkv.json -O /tmp/mkv.json`
2. Build and install plugin:  
   `iocage fetch dhcp=on vnet=on bpf=yes --name mkv --plugin-name /tmp/mkv.json --branch 'master'`


### Usage
1. Change password via FreeNAS' _Shell_:  
   `iocage exec <jail_name> passwd mkvuser`, while `jail_name` is usually `mkv`, check your jail listings.
2. Open SSH tunnel to allow connecting to the jail-local VNC:
   * openssh: `ssh -L <local_port>:127.0.0.1:5901 -N -f mkvuser@<jail_ip>`
   * PuTTy (_Connection -> SSH -> Tunnels_):

     field | value
     ----- | -----
     Source port | `<local_port>`
     Destination | `127.0.0.1:5901`

     If using host as jumpbox to jail, configure PuTTY with plink proxy (_Connection -> Proxy_):

     field | value
     ----- | -----
     Proxy hostname | `<jumpbox_ip>`
     Port | `<jumpbox_ssh_port>` (probably 22)
     Do DNS name lookup at proxy end | `No`
     Username | `<jumpbox_ssh_username>`
     Password | `<jumpbox_ssh_password\|blank_for_prompt>`
     Telnet command, or local proxy command | `plink.exe %user@%proxyhost -pw %pass -P %proxyport -nc %host:%port`

3. Connect to VNC @ `localhost:<local_port>`