# HW0
## environment setup
* OS : Windows 11
* HW
  1. Install Vivado Design Suite : [Vivado ML Edition 2023.1](https://www.xilinx.com/support/download.html)
  2. Install [Arty board file](https://github.com/Digilent/vivado-boards)
     * follow the instruction => get /aquila_mpd/ folder
* SW
  1. [安裝 WSL](https://learn.microsoft.com/zh-tw/windows/wsl/install) :
     * WSL : Windows Subsystems for Linux
     * 用系統管理員執行 cmd : `wsl --install` (Ubuntu 22.04.3 LTS)
     * 重新開機 : Error : 0x80370114 [sol](https://blog.csdn.net/m0_57298796/article/details/128395860)
  2. 安裝 [riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)
     * ```
       $ sudo apt-get install autoconf automake autotools-dev curl python3 python3-pip libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev
       ```
     * `$ git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git`
     * `$ ./configure --prefix=/opt/riscv --with-arch=rv32ima_zicsr_zifencei --with-abi=ilp32`
     * `$ sudo make`
     * `$ export PATH=$PATH:/opt/riscv/bin`
     * `$ export RISCV=/opt/riscv`
