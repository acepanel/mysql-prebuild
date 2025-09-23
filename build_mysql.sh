#!/bin/bash

channel=${1}
version=${2}
mysql_path="/opt/ace/server/mysql"

echo "Building Percona Server ${version} for ${channel}"

# 准备目录
rm -rf ${mysql_path}
mkdir -p ${mysql_path}
cd ${mysql_path}

# 下载源码
git clone --depth 1 --branch "Percona-Server-${version}" https://github.com/percona/percona-server.git src
cd src
git submodule init
git submodule update

# 编译
mkdir dist
cd dist

# 57 禁用嵌入式服务器
if [[ ${channel} == "percona_57" ]]; then
    WITHOUT_EMBEDDED="-DWITH_EMBEDDED_SERVER=0 -DWITH_EMBEDDED_SHARED_LIBRARY=0"
fi

# 57 和 80 需要 boost 和禁用 TOKUDB
if [[ ${channel} == "percona_57" ]] || [[ ${channel} == "percona_80" ]]; then
    WITH_BOOST="-DDOWNLOAD_BOOST=1 -DWITH_BOOST=${mysql_path}/src/boost"
    WITHOUT_TOKUDB="-DWITH_TOKUDB=0"
fi

# 80+ 优化
WITH_OPT="-DWITH_MYSQLX=0 -DWITH_ROUTER=0 -DWITH_LTO=1 -DCOMPRESS_DEBUG_SECTIONS=1"
if [[ ${channel} == "percona_57" ]]; then
    WITH_OPT=""
fi

cmake .. -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_INSTALL_PREFIX=${mysql_path} -DMYSQL_DATADIR=${mysql_path}/data -DSYSCONFDIR=${mysql_path}/conf -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_ARCHIVE_STORAGE_ENGINE=0 -DWITH_EXAMPLE_STORAGE_ENGINE=0 -DWITH_FEDERATED_STORAGE_ENGINE=0 -DWITH_BLACKHOLE_STORAGE_ENGINE=0 -DWITH_PARTITION_STORAGE_ENGINE=0 -DWITH_NDBCLUSTER_STORAGE_ENGINE=0 ${WITHOUT_TOKUDB} -DWITH_ROCKSDB=0 -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DMAX_INDEXES=255 -DWITH_RAPID=0 -DWITH_NDBMTD=0 -DENABLED_LOCAL_INFILE=1 -DWITHCOREDUMPER=0 -DWITH_DEBUG=0 -DWITH_UNIT_TESTS=OFF -DINSTALL_MYSQLTESTDIR= -DCMAKE_BUILD_TYPE=Release -DWITH_SYSTEMD=1 -DSYSTEMD_PID_DIR=${mysql_path} ${WITH_BOOST} ${WITH_OPT} ${WITHOUT_EMBEDDED}
if [ "$?" != "0" ]; then
    rm -rf ${mysql_path}
    echo "Compilation initialization failed"
    exit 1
fi

make "-j$(nproc)"
if [ "$?" != "0" ]; then
    rm -rf ${mysql_path}
    echo "Compilation failed"
    exit 1
fi

# 安装
make install
if [ "$?" != "0" ]; then
    rm -rf ${mysql_path}
    echo "Installation failed"
    exit 1
fi

# 清理
cd ${mysql_path}
rm -rf src
rm -rf ${mysql_path}/lib/*.a
rm -rf ${mysql_path}/bin/ldb
rm -rf ${mysql_path}/bin/mysql_ldb
rm -rf ${mysql_path}/bin/sst_dump
rm -rf ${mysql_path}/bin/mysql_client_test*
rm -rf ${mysql_path}/bin/mysqltest*
rm -rf ${mysql_path}/bin/mysql_embedded

# 精简压缩
strip -s ${mysql_path}/bin/*

echo "Build successful"
exit 0
