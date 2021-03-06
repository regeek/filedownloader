#!/bin/sh

LOG="/var/www/html/video/logs/videolog.log"
CURRENT_PASS="/var/www/html/video/"
VIDEO_PASS="/var/www/html/video/videofile/"
LIST_PASS="/var/www/html/video/listfile/"
VIDEO_LIST="${LIST_PASS}VIDEO_LIST"
VIDEO_LIST_OLD="${LIST_PASS}VIDEO_LIST_OLD"
TODAY=`date +"%Y/%m/%d"`
ONEDAY_AGO=`date +"%Y/%m/%d" -d-1day`
TWODAY_AGO=`date +"%Y/%m/%d" -d-2day`
THREEDAY_AGO=`date +"%Y/%m/%d" -d-3day`
FOURDAY_AGO=`date +"%Y/%m/%d" -d-4day`
FIVEDAY_AGO=`date +"%Y/%m/%d" -d-5day`
SIXDAY_AGO=`date +"%Y/%m/%d" -d-6day`
STR_SEARCH_DATE="$TODAY|$ONEDAY_AGO|$TWODAY_AGO|$THREEDAY_AGO|$FOURDAY_AGO|$FIVEDAY_AGO|$SIXDAY_AGO"
RETRY_CNT=0

#関数
log_msg()
{
    LOG_TITLE=$1
    echo "[`date +"%Y/%m/%d %H:%M:%S"`]LOG:$LOG_TITLE" >> $LOG
}

#MAIN
echo "##### video download script start #####"
log_msg "video download script start"

#ここでファイル名を変更しておくこと
mv $VIDEO_LIST $VIDEO_LIST_OLD

#read URL
URL=`cat ${CURRENT_PASS}URLFILE`

#csv download
while true; do
    log_msg "CSV download"
    wget -a $LOG -O "${CURRENT_PASS}video.csv" ${URL}video.csv
    if [ $? -ne 0 ]; then
        log_msg "CSV could not be retrieved"

        if [[ RETRY_CNT -eq 3 ]]; then
            #3回リトライしてダメなら終了
            log_msg "Failed to CSV of acquisition"
            log_msg "video download script end"
            exit 0
        fi
        RETRY_CNT=`expr $RETRY_CNT + 1`
        log_msg "CSV download retry start RETRY_CNT=[$RETRY_CNT]"
    else
        break
    fi
done
iconv -f SJIS-WIN -t UTF8 ${CURRENT_PASS}video.csv -o ${CURRENT_PASS}video-utf8.csv

#日付を条件に抽出
cat ${CURRENT_PASS}video-utf8.csv | grep -E $STR_SEARCH_DATE > ${LIST_PASS}TMP_VIDEO_LIST

#保存したいタイトルのみ抽出
while read TITLE
do
    cat ${LIST_PASS}TMP_VIDEO_LIST | grep $TITLE >> ${LIST_PASS}VIDEO_LIST
done < ${LIST_PASS}RECORD_VIDEO_LIST
log_msg "show VIDEO_LIST"
cat ${LIST_PASS}VIDEO_LIST >> $LOG

diff -u ${LIST_PASS}VIDEO_LIST_OLD ${LIST_PASS}VIDEO_LIST > ${LIST_PASS}TMP_VIDEO_LIST_DIFF
DIFF_RESULT=`echo $?`
log_msg "diff [VIDEO_LIST_OLD - VIDEO_LIST]"
cat ${LIST_PASS}TMP_VIDEO_LIST_DIFF >> $LOG

if [ $DIFF_RESULT -eq 1 ]; then
    #diffがあった場合
    echo "--- I discovered a new video ---"
    STR_VIDEO_ADD="+"`date +"%Y_%m"`
    cat ${LIST_PASS}TMP_VIDEO_LIST_DIFF | grep $STR_VIDEO_ADD > ${LIST_PASS}TMP_VIDEO_LIST_ADD
    sed -e "s/+//g" ${LIST_PASS}TMP_VIDEO_LIST_ADD > ${LIST_PASS}TMP_VIDEO_LIST_SED

    while read LINE
    do
       MP4FILE_NAME=`echo $LINE | cut -d',' -f1`
       MP4FILE=$MP4FILE_NAME".mp4"
       log_msg "download file $MP4FILE"
       wget -a $LOG -O "$VIDEO_PASS$MP4FILE" $URL$MP4FILE
    done < ${LIST_PASS}TMP_VIDEO_LIST_SED

else
    #diffがなかった場合
    echo "--- There is no new video ---"
    log_msg "none new video"
fi

#PHPで読み込むため、降順でsortしたファイルを作成
sort -r ${LIST_PASS}VIDEO_LIST > ${LIST_PASS}VIDEO_LIST_SORT

#TMPファイル・CSVファイルの削除
rm -f ${LIST_PASS}TMP_VIDEO_LIST
rm -f ${LIST_PASS}TMP_VIDEO_LIST_DIFF
rm -f ${LIST_PASS}TMP_VIDEO_LIST_ADD
rm -f ${LIST_PASS}TMP_VIDEO_LIST_SED
rm -f ${CURRENT_PASS}video-utf8.csv
rm -f ${CURRENT_PASS}video.csv

#一週間前の動画ファイルを削除
log_msg "1week ago mp4file delete!"
find ${VIDEO_PASS} -name "*.mp4" -mtime +6 | xargs rm -f >> $LOG

log_msg "video download script end"
echo "##### video download script end   #####"
