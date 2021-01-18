#!/bin/bash

echoHelp(){
	echo ''
	echo '<apk-package.sh>脚本使用说明:'
	echo ' 	-baseConfig             基础配置文件'
	echo ' 	-workspace              基础目录'
	echo ' 	-folder 				        基础目录下的执行打包的文件目录名'
	echo ' 	-t | -type 				      执行的命令类型：jiagu|sign|jiagu_sign|package|ready|publish'
	echo ''
}

#本地签名打包命令
#./apk-package.sh \
#  -workspace /Users/modongning/Desktop/local \
#  -folder 21011 \
#  -baseConfig /Users/modongning/soouya/workspace/auto-package-sh/resources/config/local/base.conf \
#  -type jiagu_sign

workspace_folder=''
work_folder=''
op_type=''
base_config_file=''

#################
#获取配置参数
#################
while [ -n "$1" ]
do
	case "$1" in
		-workspace)
			workspace_folder=$2
			;;
		-folder)
			work_folder=$2
			;;
    -t | -type)
        op_type=$2
        ;;
    -baseConfig)
      base_config_file=$2
      ;;
		"?")
			echoHelp
			;;
	esac
	shift
done
#################
#获取配置参数
#################

if [[ "${workspace_folder}" = '' ]] ;then
	echo '基础目录不能为空。。。'
	echoHelp
	exit 0
fi

if [[ "${work_folder}" = '' ]] ;then
	echo '工作目录不能为空。。。'
	echoHelp
	exit 0
fi

if [[ "${op_type}" = '' ]] ;then
	echo '操作类型不能为空。。。'
	echoHelp
	exit 0
fi

#判断文件是否存在
if [[ ! -f ${base_config_file} ]] ;then
	echo "${base_config_file} 配置文件不存在"
	exit 0
fi

# 目前所有的apk包，这个对应输入配置文件的包配置域
# TODO 如果需要添加新的APK打包，则需要在这里添加对应的配置域，对应package.conf的配置
packages=(
  "com_otoomo_package",
  "com_otoomo_package2"
)

exist_file(){
  if [ -e "$1" ]
  then
      return 1
  else
      return 2
  fi
}


#最终的工作目录
dowork_folder=${workspace_folder}'/'${work_folder}
config_folder=$dowork_folder'/conf'
channel_folder=$dowork_folder'/channel'
output_folder=$dowork_folder'/output'

if [ ! -e ${dowork_folder} ]; then
    echo $dowork_folder'路径不存在，请确认路径后重新执行'
    exit 0
fi
if [ ! -e ${config_folder} ]; then
    echo ${config_folder}'路径不存在，请确认路径后重新执行'
    exit 0
fi
if [ ! -e ${channel_folder} ]; then
    echo ${channel_folder}'路径不存在，请确认路径后重新执行'
    exit 0
fi


package_config_file="$config_folder/package.conf"
#判断文件是否存在
if [[ ! -f ${package_config_file} ]] ;then
	echo "${package_config_file} 配置文件不存在"
	exit 0
fi

#获取配置文件值：GetPackageConfigValue "${key}"
function GetPackageConfigValue(){
    section=$(echo $1 | cut -d '.' -f 1)
    key=$(echo $1 | cut -d '.' -f 2)
    sed -n "/\[$section\]/,/\[.*\]/{
     /^\[.*\]/d
     /^[ \t]*$/d
     /^$/d
     /^#.*$/d
     s/^[ \t]*$key[ \t]*=[ \t]*\(.*\)[ \t]*/\1/p
    }" ${package_config_file}
}

#获取配置文件值：GetBaseConfigValue "${key}"
function GetBaseConfigValue(){
    section=$(echo $1 | cut -d '.' -f 1)
    key=$(echo $1 | cut -d '.' -f 2)
    sed -n "/\[$section\]/,/\[.*\]/{
     /^\[.*\]/d
     /^[ \t]*$/d
     /^$/d
     /^#.*$/d
     s/^[ \t]*$key[ \t]*=[ \t]*\(.*\)[ \t]*/\1/p
    }" ${base_config_file}
}


common_config_key="common_config"

#360用户名
NAME=`GetBaseConfigValue "${common_config_key}.login_name"`
#360用户密码
PASSWORD=`GetBaseConfigValue "${common_config_key}.login_password"`
#工具路径
TOOLS_DIR=`GetBaseConfigValue "${common_config_key}.tools_dir"`
#加固jar包路径
JIAGU_JAR=${TOOLS_DIR}"/jiagu-tools/jiagu.jar"

#工具路径
TOOLS_DIR=`GetBaseConfigValue "${common_config_key}.tools_dir"`

JAVA_PATH=`GetBaseConfigValue "${common_config_key}.java_path"`

#密钥路径
KEY_PATH=`GetBaseConfigValue "${common_config_key}.sign_key_path"`
#密钥密码
KEY_PASSWORD=`GetBaseConfigValue "${common_config_key}.sign_password"`
#别名
KEY_ALIAS=`GetBaseConfigValue "${common_config_key}.sign_key_alias"`
#别名密码
KEY_ALIAS_PASSWORD=`GetBaseConfigValue "${common_config_key}.sign_key_alias_password"`

function  setPicKeyInfo() {
  #密钥路径
  KEY_PATH=`GetBaseConfigValue "${common_config_key}.sign_key_path"`
  #密钥密码
  KEY_PASSWORD=`GetBaseConfigValue "${common_config_key}.sign_password"`
  #别名
  KEY_ALIAS=`GetBaseConfigValue "${common_config_key}.sign_key_alias"`
  #别名密码
  KEY_ALIAS_PASSWORD=`GetBaseConfigValue "${common_config_key}.sign_key_alias_password"`
}

#设置证书账号和密码信息
setPicKeyInfo

####################
#########加固########
####################
function exec_jiagu(){
  #遍历所有需要打包的配置
	i=0
	while [ $i -lt ${#packages[@]} ]
	do
	  #配置名
		config_key=${packages[$i]}
		#是否开启渠道打包
		enable=`GetPackageConfigValue "${config_key}.enable"`

    if [[ ${enable} -eq 1 ]] ;then
      #真实包名
			package=`GetPackageConfigValue "${config_key}.package"`

      echo "开始登录360：$JAVA_PATH -jar ${JIAGU_JAR} -login ${NAME} ${PASSWORD}"
      result=`$JAVA_PATH -jar ${JIAGU_JAR} -login ${NAME} ${PASSWORD}`

      echo "导入签名: $JAVA_PATH -jar ${JIAGU_JAR} -importsign ${KEY_PATH} ${KEY_PASSWORD} ${KEY_ALIAS} ${KEY_ALIAS_PASSWORD}"
      result=`$JAVA_PATH -jar ${JIAGU_JAR} -importsign ${KEY_PATH} ${KEY_PASSWORD} ${KEY_ALIAS} ${KEY_ALIAS_PASSWORD}`

      jiafu_output_folder=$output_folder/${package}/jiagu
      #原始APK路径
      source_apk=${dowork_folder}/`GetPackageConfigValue "${config_key}.source_apk"`

      #创建加固包输出目录
      if [ -e ${jiafu_output_folder} ] ;then
        rm -r "${jiafu_output_folder}"
      fi
      mkdir -p "${jiafu_output_folder}"

      echo "执行加固命令: $JAVA_PATH -jar ${JIAGU_JAR} -jiagu ${source_apk} ${jiafu_output_folder}"
      result=`$JAVA_PATH -jar ${JIAGU_JAR} -jiagu ${source_apk} ${jiafu_output_folder}`

      error_str=`echo $result | grep '下载成功'`

      if [[ $error_str = '' ]]; then
        echo ${packages}' 加固过程失败'
        echo '<< FAIL JIAGU'
        echo ''
        exit 0
      fi

      echo "完成加固,文件存放在${jiafu_output_folder}"
      echo ''
    fi

	  let i++
	done
	echo '<< END JIAGU'
  echo ''
}

####################
######排序+重签名#####
####################
function exec_sign(){
  #遍历所有需要打包的配置
	i=0
	while [ $i -lt ${#packages[@]} ]
	do
	  #配置名
		config_key=${packages[$i]}
		#是否开启渠道打包
		enable=`GetPackageConfigValue "${config_key}.enable"`

    if [[ ${enable} -eq 1 ]] ;then

      #真实包名
			package=`GetPackageConfigValue "${config_key}.package"`

      #安卓工具包路径
      ANDROID_TOOLS_DIR=${TOOLS_DIR}/android-tools

      #对齐文件输出路径
      align_output_folde=$output_folder'/'${package}'/align'
      apk_output_folder=$output_folder'/'${package}'/apk'

      #创建输出目录
      if [ -e ${align_output_folde} ] ;then
        rm -r "${align_output_folde}"
      fi
      mkdir -p "${align_output_folde}"

      output_final_apk=${apk_output_folder}/${package}.apk
      output_align_path=${align_output_folde}/${package}.apk

      if [ -e ${apk_output_folder} ] ;then
        rm -r "${apk_output_folder}"
      fi
      mkdir -p "${apk_output_folder}"

      #加固包路径
			JIAGU_OUTPUT_PATH="$output_folder/${package}/jiagu/"`ls "$output_folder/${package}/jiagu"`

      #对齐apk文件
      echo "开始执行对齐apk： ${ANDROID_TOOLS_DIR}/zipalign -v -p 4 ${JIAGU_OUTPUT_PATH} ${output_align_path}"
      result=`${ANDROID_TOOLS_DIR}/zipalign -v -p 4 ${JIAGU_OUTPUT_PATH} ${output_align_path}`

      #重新签名
      echo "开始执行重新签名：${ANDROID_TOOLS_DIR}/apksigner sign --ks ${KEY_PATH} --ks-key-alias ${KEY_ALIAS} --ks-pass pass:${KEY_PASSWORD} --out ${output_final_apk} ${output_align_path}"
      ${ANDROID_TOOLS_DIR}/apksigner sign \
        --ks ${KEY_PATH} \
        --ks-key-alias ${KEY_ALIAS} \
        --ks-pass pass:"${KEY_PASSWORD}" \
        --out ${output_final_apk} ${output_align_path}

      echo ''
    fi

	  let i++
	done

	echo '<< END SIGN'
  echo ''
}

####################
#########打包########
####################
function exec_package(){

  #遍历所有需要打包的配置
	i=0
	while [ $i -lt ${#packages[@]} ]
	do
	  #配置名
		config_key=${packages[$i]}
		#是否开启渠道打包
		enable=`GetPackageConfigValue "${config_key}.enable"`

    if [[ ${enable} -eq 1 ]] ;then

      #真实包名
			package=`GetPackageConfigValue "${config_key}.package"`
      apk_output_folder=$output_folder'/'${package}'/apk'
      output_final_apk=${apk_output_folder}/${package}.apk

      #渠道配置文件
			CHANNEL_CONFIG_PATH=${channel_folder}'/'`GetPackageConfigValue "${config_key}.channel_file"`

      #写入渠道包
      echo "开始生成渠道包文件：$JAVA_PATH -jar ${TOOLS_DIR}/walle-cli-all.jar batch -f ${CHANNEL_CONFIG_PATH} ${output_final_apk}"
      $JAVA_PATH -jar ${TOOLS_DIR}/walle-cli-all.jar batch \
        -f ${CHANNEL_CONFIG_PATH} ${output_final_apk}

      echo ''
    fi

	  let i++
	done
	echo '<< END PACKAGE'
	echo ''
}

####################
########预发布#######
####################
ready_publish="${dowork_folder}/ready_publish"
function exec_ready_publish(){
  #创建预发布目录
  mkdir -p "${ready_publish}"

  #遍历所有需要打包的配置
	i=0
	while [ $i -lt ${#packages[@]} ]
	do
	  #配置名
		config_key=${packages[$i]}
		#是否开启渠道打包
		enable=`GetPackageConfigValue "${config_key}.enable"`


    if [[ ${enable} -eq 1 ]] ;then
      #真实包名
			package=`GetPackageConfigValue "${config_key}.package"`
      apk_output_folder=$output_folder'/'${package}'/apk'

      exist_file ${apk_output_folder}/${package}_*.apk
      value=$?
      if [ $value -eq 1 ]; then
        #移动新的apk到目录
        echo ">>预发布apk到目录: mv -f ${apk_output_folder}/${package}_*.apk ${ready_publish}/"
        mv -f ${apk_output_folder}/${package}_*.apk ${ready_publish}/

        echo ''
      fi

    fi
	  let i++
	done

  cd ${ready_publish}
	echo ">>APK包数量："`ls -l | grep "^-" | wc -l`
	echo '<< END READY_PUBLISH'
	echo ''
}

####################
#########发布########
####################
function exec_publish(){
  publish_to=`GetBaseConfigValue "${common_config_key}.publish_to"`

  if [ ! -e ${publish_to} ]; then
      echo '发布路径不存在，请确认并修改发布路径后重新执行发布'
      exit 0
  fi

  exist_file ${ready_publish}/*.apk
  value=$?
  if [ $value -eq 1 ]; then
    echo "开始发布ready_publish目录文件：mv -f ${ready_publish}/*.apk ${publish_to}/"
    mv -f ${ready_publish}/*.apk ${publish_to}/
  fi

  #遍历所有需要打包的配置
	i=0
	while [ $i -lt ${#packages[@]} ]
	do
	  #配置名
		config_key=${packages[$i]}
		#是否开启渠道打包
		enable=`GetPackageConfigValue "${config_key}.enable"`

    if [[ ${enable} -eq 1 ]] ;then

      #真实包名
			package=`GetPackageConfigValue "${config_key}.package"`
      apk_output_folder=$output_folder'/'${package}'/apk'

      echo '开始发布apk。。。'

      exist_file ${apk_output_folder}/${package}_*.apk
      value=$?
      if [ $value -eq 1 ]; then
        #移动新的apk到目录
        echo ">>发布新版本的apk: mv -f ${apk_output_folder}/${package}_*.apk ${publish_to}/"
        mv -f ${apk_output_folder}/${package}_*.apk ${publish_to}/
      fi

      echo ''
    fi

	  let i++
	done
	echo '<< END PUBLISH'
  echo ''
}

function start(){
  echo ''
  echo '开始执行脚本:'
  echo "$0 $*"
  echo ''

  if [[ ${op_type} = 'jiagu' ]]; then
    exec_jiagu
  fi
  if [[ ${op_type} = 'sign' ]]; then
    exec_sign
  fi
  if [[ ${op_type} = 'jiagu_sign' ]]; then
    exec_jiagu
    exec_sign
  fi
  if [[ ${op_type} = 'package' ]]; then
    exec_package
  fi
  if [[ ${op_type} = 'ready' ]]; then
    exec_ready_publish
  fi
  if [[ ${op_type} = 'publish' ]]; then
    exec_publish
  fi
}

start
