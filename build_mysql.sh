#!/bin/bash

channel=${1}
version=${2}
mysql_path="/opt/ace/server/mysql"

# 准备目录
rm -rf ${mysql_path}
mkdir -p ${mysql_path}
cd ${mysql_path}

# 下载源码
git clone --depth 1 --branch "Percona-Server-8.4.6-6" https://github.com/percona/percona-server.git src

# 编译
cd src
git submodule init
git submodule update
mkdir dist
cd dist

# 57 和 80 需要 boost 和禁用 TOKUDB
if [[ ${channel} == "percona_57" ]] || [[ ${channel} == "percona_80" ]]; then
    WITH_BOOST="-DDOWNLOAD_BOOST=1"
    WITHOUT_TOKUDB="-DWITH_TOKUDB=0"
fi

# 80+ 禁用 MYSQLX 和 ROUTER
WITHOUT_MYSQLX="-DWITH_MYSQLX=0"
WITHOUT_ROUTER="-DWITH_ROUTER=0"
if [[ ${channel} == "percona_57" ]]; then
    WITHOUT_MYSQLX=""
    WITHOUT_ROUTER=""
fi

cmake .. -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_INSTALL_PREFIX=${mysql_path} -DMYSQL_DATADIR=${mysql_path}/data -DSYSCONFDIR=${mysql_path}/conf -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_ARCHIVE_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DWITH_BLACKHOLE_STORAGE_ENGINE=1 ${WITHOUT_TOKUDB} -DWITH_ROCKSDB=1 -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci ${WITHOUT_ROUTER} ${WITHOUT_MYSQLX} -DWITH_RAPID=0 -DENABLED_LOCAL_INFILE=1 -DWITH_DEBUG=0 -DWITH_UNIT_TESTS=OFF -DINSTALL_MYSQLTESTDIR= -DCMAKE_BUILD_TYPE=Release -DWITH_LTO=ON -DWITH_SYSTEMD=1 -DSYSTEMD_PID_DIR=${mysql_path} ${WITH_BOOST}
if [ "$?" != "0" ]; then
    rm -rf ${mysql_path}
    error "Compilation initialization failed"
fi

make "-j$(nproc)"
if [ "$?" != "0" ]; then
    rm -rf ${mysql_path}
    error "Compilation failed"
fi

# 安装
make install
if [ "$?" != "0" ]; then
    rm -rf ${mysql_path}
    error "Installation failed"
fi

# 打包
cd ${mysql_path}
rm -rf src
7z a -mx=9 "percona-server-${version}.7z" *
if [ "$?" != "0" ]; then
    rm -rf ${mysql_path}
    error "Packaging failed"
fi

echo "Installation successful"
