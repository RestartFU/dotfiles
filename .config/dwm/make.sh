rm -rf config.h
cp "env/${ENV}.h" config.h
echo "$(cat config.def.h)" >> config.h
make

