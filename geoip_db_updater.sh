#!/bin/bash
#
# @-- file    : geoip_db_updater.sh
# @-- author  : JangjJae, Lee <cine0831@gmail.com>
# @-- version : 0.1
# @-- date    : 20160726

#set -e
#set -x

PATH="/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin"
export PATH

readonly BASE_DIR="/home/apps/GeoIP"

readonly LOG_DIR="${BASE_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/geoip_updater-$(date +'%Y%m').log"

readonly DN_URL_GEO_IP="http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry"
readonly DN_URL_GEO_LIFECITY="http://geolite.maxmind.com/download/geoip/database"
readonly DN_FILE_GEO_IP="/GeoIP.dat.gz"
readonly DN_FILE_GEO_LIFECITY="/GeoLiteCity.dat.gz"

readonly WGET="/usr/bin/wget"
readonly CURL="/usr/bin/curl"
readonly GZIP="/bin/gzip"
readonly MD5="/usr/bin/md5sum"


if [ ! -d ${BASE_DIR} ]; then
    cd ${BASE_DIR}
fi

function _logging {
    local log_var=$1
    local date=$(date +'%Y-%m-%d %H:%M:%S')

    if [ ! -d ${LOG_DIR} ]; then
       mkdir -p ${LOG_DIR}
    fi

    if [ "${log_var}" = "[BEGIN]" ]; then
        echo "" >> ${LOG_FILE}
        echo "[${date}] : ${log_var}" >> ${LOG_FILE}
    elif [ "${log_var}" = "[END]" ]; then
        echo "[${date}] : ${log_var}" >> ${LOG_FILE}
        echo "Update" > ${BASE_DIR}/check_update
    else
        echo "[${date}] : $*" >> ${LOG_FILE}
    fi
}

function _download_db {
    local retval=0

    if [ ! -d ${BASE_DIR}/old_db ]; then
        mkdir -p ${BASE_DIR}/old_db
    fi

    ${WGET} -N -P ${BASE_DIR}/download_db ${DN_URL_GEO_IP}${DN_FILE_GEO_IP}
    if [[ $? -eq 0 ]]; then
        ${GZIP} -cdf ${BASE_DIR}/download_db/${DN_FILE_GEO_IP} > ${BASE_DIR}/download_db/GeoIP.dat.new
    else
        _logging "GEOIP DB download failed."
        retval=1
    fi

    ${WGET} -N -P ${BASE_DIR}/download_db ${DN_URL_GEO_LIFECITY}${DN_FILE_GEO_LIFECITY}
    if [[ $? -eq 0 ]];then
        ${GZIP} -cdf ${BASE_DIR}/download_db/${DN_FILE_GEO_LIFECITY} > ${BASE_DIR}/download_db/GeoLiteCity.dat.new
    else
        _logging "GEOLITECITY DB download failed."
        retval=2
    fi

    return ${retval}
}

function _md5chk {
    local retval=0

    echo "GeoIP.dat:$(${MD5} ${BASE_DIR}/download_db/GeoIP.dat.new | awk '{print $1}')" > ${BASE_DIR}/download_db/md5.txt.new
    echo "GeoLiteCity.dat:$(${MD5} ${BASE_DIR}/download_db/GeoLiteCity.dat.new | awk '{print $1}')" >> ${BASE_DIR}/download_db/md5.txt.new

    if [ "$(${MD5} ${BASE_DIR}/download_db/md5.txt.new | awk '{print $1}')" != "$(${MD5} ${BASE_DIR}/md5.txt | awk '{print $1}')" ]; then 
        _logging $(/bin/mv -fv ${BASE_DIR}/md5.txt ${BASE_DIR}/old_db/md5.txt.$(date +'%Y%m'))
        _logging $(/bin/mv -fv ${BASE_DIR}/download_db/md5.txt.new ${BASE_DIR}/md5.txt)
    else
        _logging $(/bin/rm -fv ${BASE_DIR}/download_db/md5.txt.new)
        _logging "GeoIP DB is not changed."

        retval=1
    fi

    return ${retval}
}

function _db_replacement {
    local retval=0

    if [[ -f ${BASE_DIR}/download_db/GeoIP.dat.new ]]; then
        _logging $(/bin/mv -fv ${BASE_DIR}/GeoIP.dat ${BASE_DIR}/old_db/GeoIP.dat.$(date +'%Y%m'))
        _logging $(/bin/mv -fv ${BASE_DIR}/download_db/GeoIP.dat.new ${BASE_DIR}/GeoIP.dat)

        retval=$(($retval+1))
    fi

    if [[ -f ${BASE_DIR}/download_db/GeoLiteCity.dat.new ]];then
        _logging $(/bin/mv -fv ${BASE_DIR}/GeoLiteCity.dat ${BASE_DIR}/old_db/GeoLiteCity.dat.$(date +'%Y%m'))
        _logging $(/bin/mv -fv ${BASE_DIR}/download_db/GeoLiteCity.dat.new ${BASE_DIR}/GeoLiteCity.dat)

        retval=$(($retval+1))
    fi

    return ${retval}
}

function _purge {
    for i in {2..6}; do
        echo $(${WGET} --header="Host: m-img.test.com" --delete-after http://mimg-00${i}.test.com/___purge/GeoIP/check_update)
        echo $(${WGET} --header="Host: m-img.test.com" --delete-after http://mimg-00${i}.test.com/___purge/GeoIP/GeoIP.dat)
        echo $(${WGET} --header="Host: m-img.test.com" --delete-after http://mimg-00${i}.test.com/___purge/GeoIP/GeoLiteCity.dat)
        echo $(${WGET} --header="Host: m-img.test.com" --delete-after http://mimg-00${i}.test.com/___purge/GeoIP/md5.txt)
    done
}


_logging "[BEGIN]"
#_logging $(/bin/rm -fv ${BASE_DIR}${DN_FILE_GEO_IP}.* ${BASE_DIR}${DN_FILE_GEO_LIFECITY}.*)

_download_db
if [ $? -eq 0 ]; then
    _logging "GeoIP DB download success."
    _md5chk
else
    _logging "[Unsual END]"
    exit
fi

if [ $? -eq 0 ]; then
    _db_replacement
    _logging "GeoIP DB update success."
fi

if [ $? -eq 2 ]; then
    _purge
    _logging "Purging success."	
fi

_logging "[Normal END]"
