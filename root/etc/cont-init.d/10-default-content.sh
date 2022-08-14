#!/usr/bin/with-contenv sh

if [ ! -d /logs ]; then
  echo "
ERROR: '/logs' directory must be mounted
"
  exit 1
fi

if [ ! -d /config ]; then
  echo "
ERROR: '/config' directory must be mounted
"
  exit 1
fi

if [ ! -d /output ]; then
  echo "
ERROR: '/output' directory must be mounted
"
  exit 1
fi

if [ ! -d /config/data ]; then
  mkdir -p /config/data
  chown -R "${PUID}:${PGID}" /config/data
fi

if [ ! -f /config/nginx.conf ] && [ ! -n "${NO_SERVER}" ]; then
  echo "Copying default nginx.conf file to /config/nginx.conf"
  cp /defaults/nginx.conf /config/nginx.conf
  chown -R "${PUID}:${PGID}" /config/nginx.conf
fi

if [ ! -d /config/.aws ]; then
  mkdir -p /config/.aws
  chown -R "${PUID}:${PGID}" /config/.aws
fi

export AWS_SHARED_CREDENTIALS_FILE=/config/.aws/credentials
export AWS_CONFIG_FILE=/config/.aws/config

# GEOIP
if [ -n "$GEOLITE_KEY" ];then
  mkdir -p /config/GeoIP
  chown -R "${PUID}:${PGID}" /config/GeoIP
  
  curl -L -o /tmp/geolite-country.tar.gz "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${GEOLITE_KEY}&suffix=tar.gz"
  tar xzOf /tmp/geolite-country.tar.gz > /config/GeoIP/GeoIP.dat
  rm /tmp/geolite-country.tar.gz

  curl -L -o /tmp/geolite-city.tar.gz "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${GEOLITE_KEY}&suffix=tar.gz"
  tar xzOf /tmp/geolite-city.tar.gz > /config/GeoIP/GeoLiteCity.dat
  rm /tmp/geolite-city.tar.gz
fi

echo "Running initial sync"
exec s6-setuidgid "${PUID}:${PGID}" /usr/bin/flock -n /app/sync.lock /app/sync.sh
