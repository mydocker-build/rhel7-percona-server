FROM registry.access.redhat.com/rhel7
MAINTAINER Percona Development

RUN groupadd -g 200 mysql
RUN useradd -u 200 -r -g 200 -s /sbin/nologin -c "Default Application User" mysql

RUN yum install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
	&& percona-release setup ps80

# Fix Percona repo baseurl
RUN sed -i 's#$releasever#7#g' /etc/yum.repos.d/percona-*.repo

# Install Percona Server Packages and additional
RUN yum install -y \
	percona-server-server \
	percona-server-tokudb \
	percona-server-rocksdb \
	which \
	policycoreutils \
	https://repo.percona.com/percona/yum/release/7/RPMS/x86_64/jemalloc-3.6.0-1.el7.x86_64.rpm \
	&& yum clean all \
	&& rm -rf /var/cache/yum /var/lib/mysql

# purge and re-create /var/lib/mysql with appropriate ownership
RUN /usr/bin/install -m 0775 -o mysql -g root -d /var/lib/mysql /var/run/mysqld /docker-entrypoint-initdb.d \
	# comment out a few problematic configuration values
	&& find /etc/my.cnf /etc/my.cnf.d -name '*.cnf' -print0 \
	| xargs -0 grep -lZE '^(bind-address|log|user)' \
	| xargs -rt -0 sed -Ei 's/^(bind-address|log|user)/#&/' \
	# don't reverse lookup hostnames, they are usually another container
	&& echo '!includedir /etc/my.cnf.d' >> /etc/my.cnf \
	&& printf '[mysqld]\nskip-host-cache\nskip-name-resolve\n' > /etc/my.cnf.d/docker.cnf \
	# TokuDB modifications
	&& /usr/bin/install -m 0664 -o mysql -g root /dev/null /etc/sysconfig/mysql \
	&& echo "LD_PRELOAD=/usr/lib64/libjemalloc.so.1" >> /etc/sysconfig/mysql \
	&& echo "THP_SETTING=never" >> /etc/sysconfig/mysql \
	# allow to change config files
	&& chown -R mysql:root /etc/my.cnf /etc/my.cnf.d \
	&& chmod -R ug+rwX /etc/my.cnf /etc/my.cnf.d

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

COPY ps-entry.sh /docker-entrypoint.sh
CMD chmod +x /docker-entrypoint.sh

ENTRYPOINT ["./docker-entrypoint.sh"]

USER mysql
EXPOSE 3306 33060
CMD ["mysqld"]

