#!/usr/bin/env bash



startup() {
  rm -rf ~/syzworkdir/*
  qemu-system-x86_64 -m 2048 -smp 4 -chardev socket,id=SOCKSYZ,server=on,wait=no,host=localhost,port=51727 -mon chardev=SOCKSYZ,mode=control -display none -serial stdio \
    -no-reboot -name VM-0 -device virtio-rng-pci -enable-kvm -device e1000,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:9000-:22 -hda ~/FreeBSD-13.1.qcow2 -cpu host > /dev/null 2>/dev/null &

  sleep 30
}

run_sys()  {
  echo $1 $2

  startup 

  echo "c++ executor/executor.cc -o syz-executor -O1 -lpthread -DGOOS_freebsd=1 -DGOARCH_amd64=1 -DGIT_REVISION=\\\"CURRENT_GIT_REVISION\\\" $1=$2 && cp syz-executor /"
  ssh vm "c++ executor/executor.cc -o syz-executor -O1 -lpthread -DGOOS_freebsd=1 -DGOARCH_amd64=1 -DGIT_REVISION=\\\"CURRENT_GIT_REVISION\\\" $1=$2 && cp syz-executor /"
  scp vm:~/syz-executor bin/freebsd_amd64/syz-executor

  kill -9 `pgrep qemu`

  timeout 65m ./bin/syz-manager -config freebsd.cfg &

  sleep 60m

  wget 10.0.0.2:10000/rawcover
  RESULT=$(wc -l rawcover)
  
  echo "$2, $RESULT" >> out/results.csv

  mv rawcover "out/rawcover-$2.txt"

  kill -9 `pgrep syz-manager`

  wait
}

run_total_server() {

  startup

  ssh vm "c++ executor/executor.cc -o syz-executor -O1 -lpthread -DGOOS_freebsd=1 -DGOARCH_amd64=1 -DONLYSERVER=1 -DGIT_REVISION=\\\"CURRENT_GIT_REVISION\\\" && cp syz-executor /"
  scp vm:~/syz-executor bin/freebsd_amd64/syz-executor

  kill -9 `pgrep qemu`
  timeout 24h ./bin/syz-manager -config freebsd.cfg &

  sleep 23h

  wget 10.0.0.2:10000/rawcover
  
  mv rawcover "rawcover-onlyserver.out"

  kill -9 `pgrep syz-manager`

  wait
}

run_temporal_server() {
  
  startup

  ssh vm "c++ executor/executor.cc -o syz-executor -O1 -lpthread -DGOOS_freebsd=1 -DGOARCH_amd64=1 -DTEMPORAL=1 -DGIT_REVISION=\\\"CURRENT_GIT_REVISION\\\" && cp syz-executor /"
  scp vm:~/syz-executor bin/freebsd_amd64/syz-executor

  kill -9 `pgrep qemu`
  timeout 24h ./bin/syz-manager -config freebsd.cfg &

  sleep 23h 

  wget 10.0.0.2:10000/rawcover
  
  mv rawcover "rawcover-temporal.out"

  kill -9 `pgrep syz-manager`

  wait
}

run_total_kernel() {

  startup

  ssh vm "c++ executor/executor.cc -o syz-executor -O1 -lpthread -DGOOS_freebsd=1 -DGOARCH_amd64=1 -DGIT_REVISION=\\\"CURRENT_GIT_REVISION\\\" && cp syz-executor /"
  scp vm:~/syz-executor bin/freebsd_amd64/syz-executor

  kill -9 `pgrep qemu`
  timeout 24h ./bin/syz-manager -config freebsd.cfg &

  sleep 23h 

  wget 10.0.0.2:10000/rawcover
  RESULT=$(wc -l rawcover)
  
  echo "$1, $RESULT" >> results.csv

  mv rawcover "rawcover-kernel.out"

  kill -9 `pgrep syz-manager`

  wait
}

SYS_read=3
SYS_write=4
SYS_open=5
SYS_sendmsg=28
SYS_recvfrom=29
SYS_accept=30
SYS_fcntl=92
SYS_select=93
SYS_socket=97
SYS_connect=98
SYS_bind=104
SYS_setsockopt=105
SYS_listen=106
SYS_getsockopt=118
SYS_sendto=133
SYS_mmap=477
SYS_accept4=541
SYS_fstatat=552
SYS_kevent=560

# COVERAGE="$SYS_read $SYS_write $SYS_open $SYS_sendmsg $SYS_accept \
#    $SYS_socket 

COVERAGE="$SYS_mmap $SYS_accept4 $SYS_fstatat $SYS_bind $SYS_setsockopt $SYS_getsockopt $SYS_fcntl $SYS_listen $SYS_kevent"

#run_total_kernel

run_total_server

run_temporal_server


# for SYS in $COVERAGE
# do
#   run_sys -DINCLUSIVE $SYS
# done

# mkdir -p out
# touch out/results.csv

for SYS in $COVERAGE
do
  run_sys -DEXCLUSIVE $SYS
done





