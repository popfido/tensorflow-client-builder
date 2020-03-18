#!/usr/bin/env bash
# This scripts automatically run series of command to compile and generate Tensorflow serving java api
# Usage:
#       bash build.sh [-v $release_version]
set -e

# default setting
RELEASE_VERSION=1.15.0

show_usage()
{
        echo -e "\nUsage:\n  $0 [options]\n\nOptions:"
        printf "  %-20s %-40s \n" "-v, --version" "Release version of TensorFlow serving to compile, default 1.15.0."
        printf "  %-20s %-40s \n" "-h, --help" "Show help."
}

if [ $# == 0 ]; then
    echo "Using default args: release_version=${RELEASE_VERSION}."
fi

#-o或--options选项后面接可接受的短选项，如ab:c::，表示可接受的短选项为-a -b -c，
# 其中-a选项无冒号不接参数，-b选项后必须接参数，-c选项的参数为可选的, 必须紧贴选项
#-l或--long选项后面接可接受的长选项，用逗号分开，冒号的意义同短选项。
#-n选项后接选项解析错误时提示的脚本名字
ARGS=`getopt -o hv: -l help,release_version: -n 'build.sh' -- "$@"`
#将规范化后的命令行参数分配至位置参数（$1,$2,...)
eval set -- "${ARGS}"

while true
do
    case "$1" in
        -h|--help)
            show_usage;
            exit 1;;
        -v|--release_version)
            echo "Using version: $2"
            RELEASE_VERSION=$2;
            shift 2;;
        --)
            shift
            break;;
        *)
            echo "Internal error!"
            exit 1;;
    esac
done

SRC=`pwd`
PROJECT_ROOT=$SRC/tensorflow-server-client

rm -rf $PROJECT_ROOT/src/main/proto
mkdir -p $PROJECT_ROOT/src/main/proto

cd $SRC/tensorflow
git pull
git checkout $RELEASE_VERSION
rsync -arv  --prune-empty-dirs --include="*/" --include="tensorflow/core/lib/core/*.proto"  \ 
  --include='tensorflow/core/framework/*.proto' --include="tensorflow/core/example/*.proto" \ 
  --include="tensorflow/core/protobuf/*.proto" --include="tensorflow/stream_executor/*.proto" \ 
  --exclude='*' $SRC/tensorflow/tensorflow  $PROJECT_ROOT/src/main/proto/

cd $SRC/serving
git pull
git checkout $RELEASE_VERSION
rsync -arv  --prune-empty-dirs --include="*/" --include='*.proto' --exclude='*' $SRC/serving/tensorflow_serving  $PROJECT_ROOT/src/main/proto/

mvn protobuf:compile
mvn protobuf:compile-custom


