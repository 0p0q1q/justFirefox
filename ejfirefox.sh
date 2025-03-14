#!/bin/bash

mkdir -p firefox-container && cd firefox-container

cat << 'EOF' > Dockerfile
FROM alpine:latest

RUN apk update && apk add --no-cache \
    firefox \
    x11vnc \
    xvfb \
    websockify \
    fluxbox \
    git \
    netcat-openbsd \
    xdotool \
    ttf-dejavu \
    fontconfig && \
    git clone --depth 1 https://github.com/novnc/noVNC.git /usr/share/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /usr/share/novnc/utils/websockify && \
    apk del git

RUN mkdir -p /firefox-profile && \
    echo 'user_pref("browser.startup.homepage", "about:blank");' >> /firefox-profile/user.js && \
    echo 'user_pref("browser.shell.checkDefaultBrowser", false);' >> /firefox-profile/user.js && \
    echo 'user_pref("browser.window.width", 1920);' >> /firefox-profile/user.js && \
    echo 'user_pref("browser.window.height", 1080);' >> /firefox-profile/user.js && \
    echo 'user_pref("layout.css.devPixelsPerPx", "1.0");' >> /firefox-profile/user.js && \
    echo 'gfx.font_rendering.cleartype_params.rendering_mode=5' >> /firefox-profile/user.js

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080
ENTRYPOINT ["/start.sh"]
EOF

cat << 'EOF' > start.sh
#!/bin/sh

Xvfb :1 -screen 0 1920x1080x24 -dpi 96 &
export DISPLAY=:1

fluxbox &

firefox --profile /firefox-profile --no-remote &

# Wait for Firefox window
for i in $(seq 1 30); do
  sleep 1
  WINDOW_ID=$(xdotool search --onlyvisible --class "Firefox" 2>/dev/null)
  [ -n "$WINDOW_ID" ] && break
done

xdotool windowsize $WINDOW_ID 1920 1080
xdotool windowmove $WINDOW_ID 0 0

x11vnc -display :1 -passwd password -forever -shared -bg -xkb -noxrecord -noxfixes -noxdamage

while ! nc -z localhost 5900; do
  sleep 0.1
done

chmod -R 755 /usr/share/novnc
/usr/share/novnc/utils/websockify/run 8080 localhost:5900 --web=/usr/share/novnc/
EOF

docker build --no-cache -t firefox-novnc .
docker rm -f firefox-novnc 2>/dev/null
docker run -d --name firefox-novnc --memory="2g" --restart unless-stopped -p 8080:8080 firefox-novnc

echo "Access at http://localhost:8080/vnc.html | Password: password"
