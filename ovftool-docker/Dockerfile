FROM ubuntu:trusty

RUN apt update
RUN apt install -y python3-pip
RUN pip3 install cot

COPY VMware-ovftool-*.bundle /tmp/VMware-ovftool.bundle
RUN yes | bash /tmp/VMware-ovftool.bundle
