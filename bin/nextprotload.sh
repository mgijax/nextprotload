#!/bin/sh
#
#  nextprotload.sh
###########################################################################
#
#  Purpose:
#
#      This script is a wrapper around the process that loads NextProt
#      associations from an input file.
#
#  Usage:
#
#      nextprotload.sh
#
#  Env Vars:
#
#      See the configuration file
#
#      - Configuration file (nextprotload.config)
#
#  Inputs:
#
#      - An input file (${INPUT_FILE}) that contains pairs of NextProt IDs and
#        human EntrezGene IDs
#
#  Outputs:
#
#      - Log file (${NEXTPROT_LOGFILE})
#
#      - Association file (${INFILE_NAME})
#
#  Exit Codes:
#
#      0:  Successful completion
#      1:  Fatal error occurred
#
#  Assumes:  Nothing
#
#  Implementation:
#
#      This script will perform following steps:
#
#      1) Source the configuration file to establish the environment.
#      2) Verify that the input file exists.
#      3) Determine if the input file has changed since the last time that
#         the load was run. Do not continue if the input file is not new.
#      4) Create the association file from the input file.
#      5) Run sanity check on the association file.
#      6) Call the association loader.
#      7) Touch the "lastrun" file to timestamp when the load was run.
#
#  Notes:  None
#
###########################################################################

cd `dirname $0`

CONFIG=`cd ..; pwd`/nextprotload.config

#
# Make sure the configuration file exists and source it.
#
if [ -f ${CONFIG} ]
then
    . ${CONFIG}
else
    echo "Missing configuration file: ${CONFIG}"
    exit 1
fi

#
# Make sure the input file exists.
#
if [ ! -r ${INPUT_FILE} ]
then
    echo "Missing input file: ${INPUT_FILE}"
    exit 1
fi

#
# Initialize the log file.
#
LOG=${NEXTPROT_LOGFILE}
rm -rf ${LOG}
touch ${LOG}

#
# There should be a "lastrun" file in the input directory that was created
# the last time the load was run for this input file. If this file exists
# and is more recent than the input file, the load does not need to be run.
#
LASTRUN_FILE=${INPUTDIR}/lastrun
if [ -f ${LASTRUN_FILE} ]
then
    if test ${LASTRUN_FILE} -nt ${INPUT_FILE}
    then
        echo "Input file has not been updated - skipping load" | tee -a ${LOG}
        exit 0
    fi
fi

#
# Create the association file by reversing the NextProt/EntrezGene IDs from
# the input file and adding a header record. The data records in the
# association file should have the following format:
#
# EntrezGene ID <TAB> NextProt ID
#
date >> ${LOG}
echo "Create the association file" | tee -a ${LOG}
rm -f ${INFILE_NAME}
echo "Entrez Gene	neXtProt" > ${INFILE_NAME}
cat ${INPUT_FILE} | awk '{print $2"	"$1}' >> ${INFILE_NAME}

#
# Make sure the association file has a minimum number of lines before the
# association loader is called. If there was a problem with the input file,
# we don't want to remove the existing associations.
#
COUNT=`cat ${INFILE_NAME} | wc -l | sed 's/ //g'`
if [ ${COUNT} -lt ${MINIMUM_FILE_SIZE} ]
then
    echo "" >> ${LOG}
    echo "**** WARNING ****" >> ${LOG}
    echo "${INFILE_NAME} has ${COUNT} lines." >> ${LOG}
    echo "Expecting at least ${MINIMUM_FILE_SIZE} lines." >> ${LOG}
    echo "Sanity error detected in association file" | tee -a ${LOG}
    exit 1
fi

#
# Call the wrapper for the association load.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Load the associations" | tee -a ${LOG}
${ASSOCLOAD_SH} ${CONFIG} >> ${LOG}
STAT=$?
if [ ${STAT} -ne 0 ]
then
    echo "Association load failed" | tee -a ${LOG}
    exit 1
fi

#
# Touch the "lastrun" file to note when the load was run.
#
touch ${LASTRUN_FILE}

echo "" >> ${LOG}
date >> ${LOG}

exit 0
