mkdir -p target
docker build --tag codedx .
docker image save codedx --output target/codedx.tar
