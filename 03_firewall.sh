set -eu

systemctl enable firewalld && sudo systemctl start firewalld
firewall-cmd --permanent --zone=public --add-port={80/tcp,443/tcp,8090/tcp,8080/tcp,8888/tcp,5000/tcp,8443/tcp}
firewall-cmd --permanent --zone=libvirt --add-port={80/tcp,443/tcp,8090/tcp,8080/tcp,8888/tcp,5000/tcp,8443/tcp}
sudo firewall-cmd --reload
