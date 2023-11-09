#!/usr/bin/env sh

KEY_FILE=/etc/nginx/certs/atr.key
CERT_FILE=/etc/nginx/certs/atr.crt
CONF_FILE=/etc/nginx/conf.d/default.conf
HEADER_FILE=/etc/nginx/conf.d/includes/header.conf

ENABLED_CONF_PATH=/etc/nginx/conf.d/conf-enabled/

safe_unlink() {
    local file=$1
    if [[ -L "${file}" ]]; then
        unlink ${file}
    fi
}

safe_link() {
    local origin=$1
    local dest=$2
    if [[ -f "${dest}" ]]; then
      rm ${dest}
    fi
    ln -s ${origin} ${dest}
}

create_certs() {
  if [[ ! -f "${KEY_FILE}" ]] || [[ ! -f "${CERT_FILE}" ]]; then
      if [[ -z "${HOSTNAME}" ]];then
          echo "no hostname set, using localhost"
          HOSTNAME=localhost
      fi

      echo "generating a self-signed certificate"
      echo "${HOSTNAME}"
      openssl req -x509 -nodes -subj "/CN=${HOSTNAME}" -days 365 -newkey rsa:4096 -sha256 \
          -keyout ${KEY_FILE} -out ${CERT_FILE}
      chmod 400 ${KEY_FILE}
  else
      echo "using the existing cert and keys : ${CERT_FILE} / ${KEY_FILE}"
  fi
}

create_certs

echo "generating configuration file"
if [[ -z "${X_FORWARDED_HOST}" ]]; then
    X_FORWARDED_HOST='$host'
fi
if [[ -z "${X_FORWARDED_SSL}" ]]; then
    X_FORWARDED_SSL='$proxy_x_forwarded_ssl'
fi
if [[ -z "${X_FORWARDED_PROTO}" ]]; then
    X_FORWARDED_PROTO='$proxy_x_forwarded_proto'
fi
if [[ -z "${X_FORWARDED_PORT}" ]]; then
    X_FORWARDED_PORT='$proxy_x_forwarded_port'
fi
sed -i "s/__X_FORWARDED_HOST__/${X_FORWARDED_HOST}/g" ${CONF_FILE}
sed -i "s/__X_FORWARDED_SSL__/${X_FORWARDED_SSL}/g" ${CONF_FILE}
sed -i "s/__X_FORWARDED_PROTO__/${X_FORWARDED_PROTO}/g" ${CONF_FILE}
sed -i "s/__X_FORWARDED_PORT__/${X_FORWARDED_PORT}/g" ${CONF_FILE}

sed -i "s/__CSP_ALLOWED_HOST__/${HOSTNAME} cdn.ckeditor.com/g" ${HEADER_FILE}

echo "Starting nginx"

nginx -g "daemon off;"