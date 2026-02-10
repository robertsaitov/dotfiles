FROM registry.fedoraproject.org/fedora:43

COPY bindep.txt /tmp/bindep.txt
RUN dnf -y update \
  && dnf -y install python3-pip \
  && pip3 install --no-cache-dir bindep \
  && dnf -y install $(bindep -b -f /tmp/bindep.txt) \
  && dnf clean all \
  && rm -f /tmp/bindep.txt
