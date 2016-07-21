FROM akbennett/lava:debian-sid

RUN export LANG=en_US.UTF-8

RUN apt-get update && apt-get -y install postgresql

ADD preseed.txt .
RUN debconf-set-selections < /preseed.txt
RUN service postgresql start && \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get -y install lava && \
      a2dissite 000-default && \
      a2ensite lava-server && \
      hostname > /hostname  #log the hostname used during install for the slave name

RUN apt-get update && \
     apt-get -y install qemu-system 

ADD start.sh .
ADD stop.sh . 

RUN apt-get update && apt-get -y install expect
ADD createsuperuser.sh /tools/
RUN /start.sh && /tools/createsuperuser.sh && /stop.sh

ADD add-kvm-to-lava.sh /tools/
RUN /start.sh && /tools/add-kvm-to-lava.sh && \
    /usr/share/lava-server/add_device.py kvm kvm01 && \
    /usr/share/lava-server/add_device.py qemu-aarch64 qemu-aarch64-01 && \
    echo "root_part=1" >> /etc/lava-dispatcher/devices/kvm01.conf && \
    /stop.sh

# Add some basic tools and run a job on the server
ADD kvm-basic.json /tools/
ADD kvm-qemu-aarch64.json /tools/

ADD getAPItoken.sh /tools/
RUN /start.sh && /tools/getAPItoken.sh && /stop.sh

ADD submit.py /tools/
ADD submittestjob.sh .

# To add a test job, run /submittestjob.sh

#Add a Pipeline device
ADD submityaml.py /tools/
ADD qemu.yaml /tools/
RUN /start.sh && mkdir -p /etc/dispatcher-config/devices && \
    cp /usr/lib/python2.7/dist-packages/lava_scheduler_app/tests/devices/qemu01.jinja2 \
       /etc/dispatcher-config/devices/ && \
    echo "{% set arch = 'amd64' %}">> /etc/dispatcher-config/devices/qemu01.jinja2 && \
    echo "{% set base_guest_fs_size = 2048 %}" >> /etc/dispatcher-config/devices/qemu01.jinja2 && \
    lava-server manage device-dictionary --hostname qemu01 \
       --import /etc/dispatcher-config/devices/qemu01.jinja2 && \
    /stop.sh

# Add additional packages for usability
#  -- Add SSH
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN echo 'root:password' | chpasswd
EXPOSE 22

# Install basic tools for physical device control
RUN apt-get update && \
     apt-get -y install vim && \
     apt-get -y install android-tools-fastboot && \
     apt-get -y install cu && \
     apt-get -y install screen 


EXPOSE 80

# Uncomment add-kvm-to-lava.sh and rebuild to test.
CMD bash -C '/start.sh'; \
            '/usr/sbin/sshd'; \
            '/bin/bash'
