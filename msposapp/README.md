POS Container Service<br>
<br>
Build Customer Specific Image<br>
<br>
$cd dockerfiles<br>
$docker build --rm -t local/centos7-rti .<br>
<br>
./dockerfiles/Dockerfile has the build configuration for Docker. (Do not change)<br>
<br>
Run a Container from Image<br> 
<br>
$docker run -ti -v /sys/fs/cgroup:/sys/fs/cgroup:ro -p 22:22 local/centos7-rti<br>
<br>
Build a Container<br>
<br>
$./bin/containerbuild.sh ./config/centos7-rti-docker.ks<br>
After you've run this command, your rootfs tarball and Dockerfile will be waiting for you in /var/tmp/containers/<datestamp>/<br>
<br>
Import the Docker Container<br>
<br>
cat centos-version-docker.tar.xz | docker import - container-name
<br>
Or you can create a Dockerfile to build the image directly in docker.
<br>
FROM scratch
<br>
MAINTAINER you<your@email.here> - ami_creator
<br>
ADD centos-version-docker.tar.xz /
<br>
