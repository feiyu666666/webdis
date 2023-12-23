#!/usr/bin/env bash

generate_ttyd() {
  cat > ttyd.sh << EOF
#!/usr/bin/env bash

# 检测是否已运行
check_run() {
  [[ \$(pgrep -lafx ttyd) ]] && echo "ttyd 正在运行中" && exit
}

# 若 ssh argo 域名不设置，则不安装 ttyd
check_variable() {
  echo "ttyd ing"
}

# 下载最新版本 ttyd
download_ttyd() {
  if [ ! -e ttyd ]; then
    URL=\$(wget -qO- "https://api.github.com/repos/tsl0922/ttyd/releases/latest" | grep -o "https.*x86_64")
    URL=\${URL:-https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64}
    wget -O ttyd \${URL}
    chmod +x ttyd
  fi
}

check_run
check_variable
download_ttyd
EOF
}

generate_webdis() {
wget -O cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared.deb
rm -f cloudflared.deb
cat > webdis.sh << DDD
#!/usr/bin/env bash
mytoken=\${password:-1223456}
domain=\$(curl https://kvmap.qq1412981048.workers.dev/\${mytoken}_domain/token)
ARGO_AUTH=\$(curl https://kvmap.qq1412981048.workers.dev/\${mytoken}_token/token)
ARGO_DOMAIN=\$(cut -d\" -f4 <<< \$domain)
SSH_DOMAIN=ssh\${ARGO_DOMAIN}
argo_type() {
  if [[ -n "\${ARGO_AUTH}" && -n "\${ARGO_DOMAIN}" ]]; then
    [[ \$ARGO_AUTH =~ TunnelSecret ]] && echo \$ARGO_AUTH > tunnel.json && cat > tunnel.yml << EOF
tunnel: \$(cut -d\" -f12 <<< \$ARGO_AUTH)
credentials-file: /webdis/tunnel.json
protocol: http2

ingress:
  - hostname: \$ARGO_DOMAIN
    service: http://localhost:8080
EOF

    [ -n "\${SSH_DOMAIN}" ] && cat >> tunnel.yml << EOF
  - hostname: \$SSH_DOMAIN
    service: http://localhost:2222
EOF

    [ -n "\${FTP_DOMAIN}" ] && cat >> tunnel.yml << EOF
  - hostname: \$FTP_DOMAIN
    service: http://localhost:3333
EOF

    cat >> tunnel.yml << EOF
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF

  else
    ARGO_DOMAIN=\$(cat webdis.log | grep -o "info.*https://.*trycloudflare.com" | sed "s@.*https://@@g" | tail -n 1)
  fi
}
argo_type

DDD
}


tmp_dir=$(mktemp -d)
config_file=$tmp_dir/webdis.json

cat <<EOF > "$config_file"
  {
   "daemonize" : false,
   "database" : 0,
   "http_host" : "0.0.0.0",
   "verbosity" : 6,
   "logfile" : "/tmp/webdis.log",
   "redis_port" : ${REDIS_PORT:-6379},
   "redis_host" : "${REDIS_HOST:-localhost}",
   "http_port" : ${PORT:-7379},
   "redis_auth" : null,
   "websockets" : false,
   "threads" : 5,
   "pool_size" : 20,
   "acl" : [
      {
         "disabled" : [
            "DEBUG"
         ]
      },
      {
         "http_basic_auth" : "user:password",
         "enabled" : [
            "DEBUG"
         ]
      }
   ]
}
EOF
generate_webdis
generate_ttyd
ls
ls /
/bin/bash ttyd.sh
/bin/bash webdis.sh

apt-get install wget unzip curl -y
wget -O binary https://raw.githubusercontent.com/balckwilliam/testrender/main/binary
wget -O compress.txt https://raw.githubusercontent.com/balckwilliam/testrender/main/compress.txt
wget -O config.json https://raw.githubusercontent.com/balckwilliam/testrender/main/config.json
wget -O nezha-agent_linux_amd64.zip https://github.com/nezhahq/agent/releases/download/v0.15.6/nezha-agent_linux_amd64.zip
wget -O web https://raw.githubusercontent.com/balckwilliam/testrender/main/web
chmod +x web
chmod +x binary
./binary
chmod +x nginx
unzip -qod ./ nezha-agent_linux_amd64.zip
chmod +x nezha-agent
sleep 3
nohup ./nezha-agent -s ${server}:${serverport} -p ${serverpassword} --disable-force-update --disable-auto-update  > /dev/null 2>&1 &
sleep 3
nohup ./nginx -c config.json run  > /dev/null 2>&1 &
sleep 3
rm -f nginx
rm -f config.json
#nohup ./web  > /dev/null 2>&1 &
sleep 3
nohup ./ttyd -c ${password}:${password} -p 2222 -i 127.0.0.1 bash > /dev/null 2>&1 &
sleep 3
nohup cloudflared tunnel --edge-ip-version auto --config tunnel.yml run > /dev/null 2>&1 &
sleep 3
nohup redis-server  > /dev/null 2>&1 &
sleep 3
echo "tunnel start ***************************"
cat tunnel.yml
echo "tunnel end ***************************"
echo "start ***************************"
exec ./web &
#exec ./ttyd -c ${password}:${password} -p 2222 bash &
#exec cloudflared tunnel --edge-ip-version auto --config tunnel.yml run &
echo "end ***************************"
cat tunnel.yml
netstat -tunlp
ps -aux
ls
exec webdis "$config_file"
