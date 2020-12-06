#!/bin/sh

# create mkvuser with default pass
USER="mkvuser"
USERHOME="/home/mkvuser"
USERPASS="changeme"
echo "$USERPASS" | pw add user -n "$USER" -c "$USER" -G wheel -h 0 -m -s /usr/local/bin/bash -d "$USERHOME"
echo "%wheel ALL=(ALL) ALL" > /usr/local/etc/sudoers.d/allow_wheel

# Enable sshd password auth
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# patch vncserver script:
# 1. use xfce instead of twm
# 2. remove need for password, localhost vnc only
# 3. fix detecting port
VNCSERVER="/usr/local/bin/vncserver"
VNCSERVER_PERMS=$(stat -f '%OLp' "$VNCSERVER")
chmod u+w "$VNCSERVER"
cat << "VNCSERVERPATCH" | patch "$VNCSERVER"
diff --git a/vncserver b/vncserver
index 97cb3f3..ee50563 100644
--- a/vncserver
+++ b/vncserver
@@ -51,7 +51,7 @@ $defaultXStartup
        "xrdb \$HOME/.Xresources\n".
        "xsetroot -solid grey\n".
        "xterm -geometry 80x24+10+10 -ls -title \"\$VNCDESKTOP Desktop\" &\n".
-       "twm &\n");
+       "startxfce4 &\n");
 
 $xauthorityFile = "$ENV{XAUTHORITY}";
 
@@ -111,20 +111,6 @@ if (!-d _ || !-o _ || ($vncUserDirUnderTmp && ($mode & 0777) != 0700)) {
     die "$prog: Wrong type or access mode of $vncUserDir.\n";
 }
 
-# Make sure the user has a password.
-
-($z,$z,$mode) = lstat("$vncUserDir/passwd");
-if (-e _ && (!-f _ || !-o _)) {
-    die "$prog: Wrong type or ownership on $vncUserDir/passwd.\n";
-}
-if (!-e _ || ($mode & 077) != 0) {
-    warn "\nYou will require a password to access your desktops.\n\n";
-    system("vncpasswd $vncUserDir/passwd");
-    if (($? & 0xFF00) != 0) {
-        exit 1;
-    }
-}
-
 # Find display number.
 
 if ((@ARGV > 0) && ($ARGV[0] =~ /^:(\d+)$/)) {
@@ -167,7 +153,6 @@ $cmd .= " -geometry $geometry" if ($geometry);
 $cmd .= " -depth $depth" if ($depth);
 $cmd .= " -pixelformat $pixelformat" if ($pixelformat);
 $cmd .= " -rfbwait 120000";
-$cmd .= " $authType";
 $cmd .= " -rfbport $vncPort";
 $cmd .= " -fp $fontPath" if ($fontPath);
 $cmd .= " -co $colorPath" if ($colorPath);
@@ -296,7 +281,7 @@ sub CheckDisplayNumber
 
     socket(S, $AF_INET, $SOCK_STREAM, 0) || die "$prog: socket failed: $!\n";
     eval 'setsockopt(S, &SOL_SOCKET, &SO_REUSEADDR, pack("l", 1))';
-    unless (bind(S, pack('S n x12', $AF_INET, 6000 + $n))) {
+    unless (bind(S, sockaddr_in(6000 + $n, &INADDR_ANY))) {
 	close(S);
 	return 0;
     }
@@ -304,7 +289,7 @@ sub CheckDisplayNumber
 
     socket(S, $AF_INET, $SOCK_STREAM, 0) || die "$prog: socket failed: $!\n";
     eval 'setsockopt(S, &SOL_SOCKET, &SO_REUSEADDR, pack("l", 1))';
-    unless (bind(S, pack('S n x12', $AF_INET, 5900 + $n))) {
+    unless (bind(S, sockaddr_in(5900 + $n, &INADDR_ANY))) {
 	close(S);
 	return 0;
     }
VNCSERVERPATCH
chmod "$VNCSERVER_PERMS" "$VNCSERVER"

#$pidFile = "$vncUserDir/$host:$displayNumber.pid";

# Add service to autostart vncserver
VNCDISP=1
VNCSERVER_SERVICE="/usr/local/etc/rc.d/vncserver"
cat << VNCSS > "$VNCSERVER_SERVICE"
#!/bin/sh

# PROVIDE: vncserver
# REQUIRE: LOGIN FILESYSTEMS
# KEYWORDS: shutdown

. /etc/rc.subr
export PATH="/usr/local/bin:$PATH"
name=vncserver
rcvar=vncserver_enable
command="/usr/local/bin/vncserver"
command_args="-geometry 1920x1080 -depth 24 -localhost -desktop \$(hostname -s) -nevershared -rfbport 590${VNCDISP} :${VNCDISP}"
procname="Xvnc"
vncserver_user="$USER"
stop_cmd="\${name}_stop"
status_cmd="\${name}_status"
start_cmd="\${name}_start"

vncserver_status(){
  if pid=\$(pgrep "\$procname"); then
    echo "vncserver is running as pid \${pid}."
  else
    echo "vncserver is not running."
    return 1
  fi
}

vncserver_start(){
  if ! vncserver_status >/dev/null; then
    su "\$vncserver_user" -c "\"\$command\" \$command_args"
  fi
}

vncserver_stop(){
  # hacky...should use something to ensure all vnc sessions are killed
  su "\$vncserver_user" -c "\"\$command\" -kill :1" || true
}

load_rc_config "\$name"
run_rc_command "\$1"
VNCSS
chmod 555 "$VNCSERVER_SERVICE"

# Enable services
# xfce requires dbus service
sysrc -f /etc/rc.conf dbus_enable="YES" 2>/dev/null
sysrc -f /etc/rc.conf sshd_enable="YES" 2>/dev/null
sysrc -f /etc/rc.conf vncserver_enable="YES" 2>/dev/null

# Start the services
service dbus start 2>/dev/null
service sshd start 2>/dev/null
service vncserver start 2>/dev/null

PLUGIN_INFO="/root/PLUGIN_INFO"
cat << INFO | tee "$PLUGIN_INFO"
Username: ${USER}
Password: ${USERPASS}
VNC Display: :${VNCDISP}
INFO

cat << PASSWD

IMPORTANT: Change ${USER}'s password with:

  iocage exec <my_jail_name> passwd ${USER}
PASSWD