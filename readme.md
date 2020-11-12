```
git clone git@github.com:ciiqr/installer-void.git
git submodule update --init
cd mklive
make
cd -
sudo ./generate.sh
./test.sh "$(basename $(realpath ./))" mklive/installer-void-x86_64-$(ymd).iso
```
