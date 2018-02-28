# service-manager

A basic Docker container manager with ipvs, systemd and CouchDb.

Amazing features:
 * rolling deployment of containers
 * systemd service dependencies
 * versioned service definition with CouchDb
 * simple implementation with bash

Requirements:
 * systemd
 * ipvsadm + ip_vs kernel module (available on CoreOS)
 * CouchDb
 * bash, jq, curl, ncat (also available on CoreOS)

## What this is

The goal of `service-manager` is to run Docker containers in a way that allows
rolling deployment without down-time, with zero dependencies (okay, this thing
depends on CouchDb, but it can easily be re-implemented to use files on disk
instad). To make this possible it uses a simple service abstraction on top of
containers.

There are many other solutions for this problem (swarm, kubernetes,
consul+haproxy, ...), but most of them are rather complex to operate,
especially have a single node or don't require container-to-container
communication.

However, if you aren't already using CouchDb, you're will probably be happier
with Docker Swarm :)

## How it's supposed to work

The service manager is based on multi-instance systemd unit files. For a
service there are two types of systemd instances: the manager instance and the
runner instance.

The manager instance (`my-service@manager`) periodically fetches the latest
service definition from CouchDb and starts a systemd instance with the document
revision as instance id, for example
`my-service@1-62d4023616ab1e7921f74f650aab51e1`. If the latest instance is
already running, it will stop all previous instances. The manager also creates
an ipvs "virtual service" on the `service address`. The service address should
be used to access the service.

The service instance will start a Docker container based on the service
definition document, wait for it to be ready for traffic, and add it to the
load balancer. When the container exit, it will be removed from the load
balancer and the service stops.

## Service definition

Configuration documents must be avaiable on `$COUCHDB_URL/$service_id` and may
look like this:

```json
{
  "_id": "my-service",
  "_rev": "[ created by CouchDb]",
  "port": 80,
  "health_check": "http",
  "environment": {
    "THING": "xyz"
  },
  "volumes": [
    "/some-mount:/some-mount:ro"
  ],
  "nginx:latest"
}
```

## Example systemd unit

In this example, 172.18.0.1:7001 is the service address. The service address
must be unique for each service and the IP address must be a real address on
the host. For local-only services it is wise to use the IP address of `docker0`
since other containers running in bridge mode may then access the service.

```
[Unit]
Description=My Service

Requires=docker.service
Wants=couchdb.service
After=docker.service couchdb.service

[Service]
Environment=COUCHDB_URL=http://127.0.0.1:5984/services
ExecStart=/opt/service-manager/launch %p %i 172.18.0.1:7001
Type=notify
TimeoutSec=infinity

[Install]
WantedBy=multi-user.target
```

If you want your service to depend on other service-manager-based services, you
must depend on the manager instance (`Wants=another-service@manager`) otherwise
things will break.

System unit file reference:
https://www.freedesktop.org/software/systemd/man/systemd.unit.html

## Example usage

* `systemctl start my-service@manager` - start the manager (which in turn will
                                         start instances)

* `systemctl stop my-service@manager` - stop the manager (which in turn will
                                        stop all running instances)

* `systemctl status 'my-service@*` - check the status on manager and all
                                     instances.

* `ipvsadm -L -n` - check the current ipvs configuration

