#!/bin/bash

function riasset_get_dir() {
  if [ "$1" == "" ]; then
    echo $(pwd)
  else
    echo $(cd "${1}"; pwd)
  fi
}

export SOURCE_DIR=$(riasset_get_dir "${1}")
export TARGET_DIR=$(riasset_get_dir "${2}")
export TEMP_DIR="${TARGET_DIR}/__riasset_tmp"

export LOG_NAME="riasset.log.txt"
export DUPE_LOG="${TARGET_DIR}/riasset-dupe.log.txt"
export MAIN_LOG="${TARGET_DIR}/${LOG_NAME}"
export ERR_LOG="${TARGET_DIR}/err.log.txt"


function riasset_dedupe() {
  FILE=$1
  HASH=$(md5 -q "${FILE}")
  SIZE=$(ls -l "${FILE}" | awk '{print $5}')
  NAME=$(basename "${FILE}")
  TEMP_TARGET_DIR="${TEMP_DIR}/${HASH:0:2}/${HASH:2:2}/${HASH:4:2}"
  TEMP_TARGET_FILE="${TEMP_TARGET_DIR}/${HASH}-${SIZE}"
  
  if [ -f "${TEMP_TARGET_FILE}" ]; then
	echo "${FILE}" >> "${DUPE_LOG}"
	exit
  fi
  
  mkdir -p "${TEMP_TARGET_DIR}"
  echo "${FILE}" >> "${TEMP_TARGET_DIR}/${LOG_NAME}"

  chflags nouchg "${FILE}"
  mv -f "${FILE}" "${TEMP_TARGET_FILE}" 2>> "${ERR_LOG}"
  echo "${FILE} -> ${TEMP_TARGET_FILE}" >> "${MAIN_LOG}"
}

export -f riasset_dedupe

find -E "${SOURCE_DIR}" -iregex ".*\.(jpe?g|gif|png|tiff?|bmp|mp3|mpg|mp4|mov|avi|mkv)$" -type f -exec bash -c 'riasset_dedupe "$1"' _ {} \;


function riasset_move() {
  FILE=$1
  
  SIZE=$(ls -l "${FILE}" | awk '{print $5}')
  if [ $SIZE -lt 65536 ]; then
    SIZE_CLASS="1-small"
  elif [ $SIZE -lt 1048576 ]; then
    SIZE_CLASS="2-medium"
  elif [ $SIZE -lt 134217728 ]; then
    SIZE_CLASS="3-large"
  else
    SIZE_CLASS="4-huge"
  fi

  DIR=$(dirname "${FILE}")
  SOURCE_FILE=$(head -1 "${DIR}/${LOG_NAME}")
  TARGET_FILE=${SOURCE_FILE/"${SOURCE_DIR}"/"${TARGET_DIR}/${SIZE_CLASS}"}

  if [ -f "${TARGET_FILE}" ]; then
	echo "Destination file already exists: ${FILE} ${TARGET_FILE}" >> "${ERR_LOG}"
	exit
  fi

  TARGET_FILE_DIR=$(dirname "${TARGET_FILE}")
  mkdir -p "${TARGET_FILE_DIR}"

  mv -f "${FILE}" "${TARGET_FILE}" 2>> "${ERR_LOG}"
  echo "${FILE} -> ${TARGET_FILE}" >> "${MAIN_LOG}"
}

export -f riasset_move

find -E "${TEMP_DIR}" -type f -not -name "${LOG_NAME}" -exec bash -c 'riasset_move "$1"' _ {} \;
