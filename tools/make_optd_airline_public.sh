#!/bin/bash

# Create the public version of the ORI-maintained list of airlines, from:
# - optd_airline_best_known_so_far.csv
# - optd_airline_no_longer_valid.csv
# - ref_airline_nb_of_flights.csv (future)
# - optd_airline_alliance_membership.csv
# - dump_from_crb_airline.csv
# - dump_from_geonames.csv (future)
#
# => optd_airlines.csv
#

##
# Temporary path
TMP_DIR="/tmp/por"

##
# Path of the executable: set it to empty when this is the current directory.
EXEC_PATH=`dirname $0`
# Trick to get the actual full-path
pushd ${EXEC_PATH} > /dev/null
EXEC_FULL_PATH=`popd`
popd > /dev/null
EXEC_FULL_PATH=`echo ${EXEC_FULL_PATH} | sed -e 's|~|'${HOME}'|'`
#
CURRENT_DIR=`pwd`
if [ ${CURRENT_DIR} -ef ${EXEC_PATH} ]
then
	EXEC_PATH="."
	TMP_DIR="."
fi
# If the Geonames dump file is in the current directory, then the current
# directory is certainly intended to be the temporary directory.
if [ -f ${GEO_RAW_FILENAME} ]
then
	TMP_DIR="."
fi
EXEC_PATH="${EXEC_PATH}/"
TMP_DIR="${TMP_DIR}/"

if [ ! -d ${TMP_DIR} -o ! -w ${TMP_DIR} ]
then
	\mkdir -p ${TMP_DIR}
fi

##
# Sanity check: that (executable) script should be located in the
# tools/ sub-directory of the OpenTravelData project Git clone
EXEC_DIR_NAME=`basename ${EXEC_FULL_PATH}`
if [ "${EXEC_DIR_NAME}" != "tools" ]
then
	echo
	echo "[$0:$LINENO] Inconsistency error: this script ($0) should be located in the refdata/tools/ sub-directory of the OpenTravelData project Git clone, but apparently is not. EXEC_FULL_PATH=\"${EXEC_FULL_PATH}\""
	echo
	exit -1
fi

##
# OpenTravelData directory
OPTD_DIR=`dirname ${EXEC_FULL_PATH}`
OPTD_DIR="${OPTD_DIR}/"

##
# ORI sub-directories
ORI_DIR=${OPTD_DIR}ORI/
TOOLS_DIR=${OPTD_DIR}tools/

##
# Log level
LOG_LEVEL=3

##
# File of best known airline details (future)
ORI_AIR_FILENAME=optd_airline_best_known_so_far.csv
# File of no longer valid IATA entries (future)
ORI_NOIATA_FILENAME=optd_airline_no_longer_valid.csv
# File of alliance membership details
ORI_AIR_ALC_FILENAME=optd_airline_alliance_membership.csv
#
ORI_AIR_FILE=${ORI_DIR}${ORI_AIR_FILENAME}
ORI_NOIATA_FILE=${ORI_DIR}${ORI_NOIATA_FILENAME}
ORI_AIR_ALC_FILE=${ORI_DIR}${ORI_AIR_ALC_FILENAME}

##
# Importance values (future)
ORI_NF_FILENAME=ref_airline_nb_of_flights.csv
ORI_NF_FILE=${ORI_DIR}${ORI_NF_FILENAME}

##
# RFD (to be found, as temporary files, within the ../tools directory)
RFD_AIR_FILENAME=dump_from_crb_airline.csv
#
RFD_AIR_FILE=${TOOLS_DIR}${RFD_AIR_FILENAME}
# RFD with primary key (generated by the
# ../tools/prepare_rfd_dump_file.sh script)
RFD_CAP_FILENAME=cap_${RFD_AIR_FILENAME}
#
RFD_CAP_FILE=${TOOLS_DIR}${RFD_CAP_FILENAME}

##
# Target (generated files)
ORI_AIR_PUBLIC_FILENAME=optd_airlines.csv
ORI_AIR_RFD_DIFF_FILENAME=optd_airline_diff_w_rfd.csv
ORI_AIR_ALC_DIFF_FILENAME=optd_airline_diff_w_alc.csv
#
ORI_AIR_PUBLIC_FILE=${ORI_DIR}${ORI_AIR_PUBLIC_FILENAME}
ORI_AIR_RFD_DIFF_FILE=${ORI_DIR}${ORI_AIR_RFD_DIFF_FILENAME}
ORI_AIR_ALC_DIFF_FILE=${ORI_DIR}${ORI_AIR_ALC_DIFF_FILENAME}

##
# Temporary
ORI_AIR_HEADER=${ORI_AIR_FILE}.tmp.hdr
ORI_AIR_WITH_NOHD=${ORI_AIR_FILE}.wohd
ORI_AIR_UNSORTED_NOHDR=${ORI_AIR_FILE}.wohd.unsorted
ORI_AIR_PUBLIC_UNSORTED_FILE=${ORI_AIR_FILE}.unsorted


##
# Sanity check
if [ ! -d ${TOOLS_DIR} ]
then
	echo
	echo "[$0:$LINENO] The tools/ sub-directory ('${TOOLS_DIR}') does not exist or is not accessible."
	echo "Check that your Git clone of the OpenTravelData is complete."
	echo
	exit -1
fi
if [ ! -f ${TOOLS_DIR}prepare_rfd_dump_file.sh ]
then
	echo
	echo "[$0:$LINENO] The RFD file preparation script ('${TOOLS_DIR}prepare_rfd_dump_file.sh') does not exist or is not accessible."
	echo "Check that your Git clone of the OpenTravelData is complete."
	echo
	exit -1
fi


##
# Usage helper
#
if [ "$1" = "-h" -o "$1" = "--help" ]
then
	echo
	echo "That script generates the public version of the ORI-maintained list of airlines"
	echo
	echo "Usage: $0 [<log level (0: quiet; 5: verbose)>]"
	echo " - Default log level (from 0 to 5): ${LOG_LEVEL}"
	echo
	echo "* Input data files"
	echo "------------------"
	echo " - ORI-maintained file of best known details: '${ORI_AIR_FILE}'"
	echo " - ORI-maintained file of non longer valid IATA airlines: '${ORI_NOIATA_FILE}'"
	echo " - ORI-maintained file of importance values: '${ORI_NF_FILE}'"
	echo " - ORI-maintained file of alliance membership details: '${ORI_AIR_ALC_FILE}'"
	echo " - RFD data dump file: '${RFD_AIR_FILE}'"
	echo
	echo "* Output data file"
	echo "------------------"
	echo " - ORI-maintained public file of airlines: '${ORI_AIR_PUBLIC_FILE}'"
	echo " - List of airlines for which the RFD-derived names are different: '${ORI_AIR_RFD_DIFF_FILE}'"
	echo " - List of airlines for which the alliance-derived names are different: '${ORI_AIR_ALC_DIFF_FILE}'"
	echo
	exit
fi


##
# Cleaning
#
if [ "$1" = "--clean" ]
then
	\rm -f ${ORI_AIR_WITH_NOHD} ${ORI_AIR_UNSORTED_NOHDR} \
		${ORI_AIR_PUBLIC_UNSORTED_FILE} ${RFD_CAP_FILE}

	bash prepare_rfd_dump_file.sh --clean || exit -1
	exit
fi


##
# Log level
if [ "$1" != "" ]
then
	LOG_LEVEL="$1"
fi


##
# Preparation
bash prepare_rfd_dump_file.sh ${OPTD_DIR} ${TOOLS_DIR} ${LOG_LEVEL} || exit -1

##
#
if [ ! -f ${RFD_CAP_FILE} ]
then
	echo
	echo "[$0:$LINENO] The '${RFD_CAP_FILE}' file does not exist."
	echo
	exit -1
fi

##
# Re-format the aggregated entries. See ${REDUCER} for more details and samples.
REDUCER=make_optd_airline_public.awk
awk -F'^' -v air_name_alc_diff_file=${ORI_AIR_ALC_DIFF_FILE} \
	-v air_name_rfd_diff_file=${ORI_AIR_RFD_DIFF_FILE} \
	-f ${REDUCER} ${ORI_AIR_ALC_FILE} ${ORI_NF_FILE} \
	${ORI_AIR_FILE} ${ORI_NOIATA_FILE} ${RFD_CAP_FILE} \
	> ${ORI_AIR_PUBLIC_UNSORTED_FILE}

##
# Extract the header into temporary files
grep "^pk\(.\+\)" ${ORI_AIR_PUBLIC_UNSORTED_FILE} > ${ORI_AIR_HEADER}

##
# Remove the header
sed -e "s/^pk\(.\+\)//g" ${ORI_AIR_PUBLIC_UNSORTED_FILE} \
	> ${ORI_AIR_WITH_NOHD}
sed -i -e "/^$/d" ${ORI_AIR_WITH_NOHD}

##
# Sort on the IATA code, feature code and Geonames ID, in that order
sort -t'^' -k1,1 -k2,2 ${ORI_AIR_WITH_NOHD} > ${ORI_AIR_UNSORTED_NOHDR}

##
# Re-add the header
cat ${ORI_AIR_HEADER} ${ORI_AIR_UNSORTED_NOHDR} > ${ORI_AIR_PUBLIC_FILE}

##
# Remove the header
\rm -f ${ORI_AIR_HEADER}

##
# Reporting
#
echo
echo "Reporting Step"
echo "--------------"
echo
echo "wc -l ${ORI_AIR_PUBLIC_FILE} ${ORI_AIR_RFD_DIFF_FILE} ${ORI_AIR_ALC_DIFF_FILE}"
echo
