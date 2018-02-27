# service-manager

Basic Docker container management with ipvs, systemd and CouchDb.

## How it's meant to work

The service manager is based on multi-instance systemd unit files. For a
service there are two types of systemd instances: the manager instance and the
actual service instance.

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

Configuration documents are currently assumed to be located in CouchDb on
`http://127.0.0.1:5984/service/$service_id` and may look like this:

```json
{
  "_id": "my-service",
  "_rev": "[ created by CouchDb]",
  "port": 80,
  "environment": {
    "THING": "xyz"
  },
  "volumes": [
    "/mnt/store0:/mnt/store0"
  ],
  "nginx:latest"
}
```

## Example systemd unit
In this example, 172.18.0.1:7001 is the service address. The service address
must be unique for each service and the IP address must be a real address on
the host. For local-only services it is wise to use the IP address of `docker0`
since other containers running in bridge mode may then access the service.

```toml
[Unit]
Description=My Service

Requires=docker.service
After=docker.service

[Service]
ExecStart=/opt/service-manager/launch %p %i 172.18.0.1:7001
Type=notify
TimeoutSec=infinity

[Install]
WantedBy=multi-user.target
```

## Example usage

* `systemctl start my-service@manager` - start the manager (which in turn will
                                         start instances)

* `systemctl stop my-service@manager` - stop the manager (which in turn will
                                        stop all running instances)

* `systemctl status 'my-service@*` - check the status on manager and all
                                     instances.

* `ipvsadm -L -n` - check the current ipvs configuration

