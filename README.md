# Consul Backups to s3
Docker container for backing up Consul

## Prerequisites

* A Consul cluster to restore to or backup from
* Already authenticated with s3 via assumed-role or some other method.

## Usage

To backup only:

```
  docker run \
  -e CONSUL_ARGS="-config-dir=/consul/config" \
  -e S3_URL=s3://my-bucket/consul-backups/ \
  -v $(pwd)/consul-config:/consul/config \
  thorix/consul-backup
```

To restore only:

```
  docker run \
  -e CONSUL_ARGS="-config-dir=/consul/config" \
  -e BACKUP=false \
  -e RESTORE_FILE=s3://my-bucket/consul-backups/consul-20180215.122934.snap \
  -v $(pwd)/consul-config:/consul/config \
  thorix/consul-backup
```

To restore then backup:

```
  docker run \
  -e CONSUL_ARGS="-config-dir=/consul/config" \
  -e S3_URL=s3://my-bucket/consul-backups/ \
  -e RESTORE_FILE=s3://my-bucket/consul-backups/consul-20180215.122934.snap \
  -v $(pwd)/consul-config:/consul/config \
  thorix/consul-backup
```

### Environment Variables

To customize some properties of the container, the following environment
variables can be passed via the `-e` parameter (one for each variable).  Value
of this parameter has the format `<VARIABLE_NAME>=<VALUE>`.

| Variable       | Description                                  | Default/Required |
|----------------|----------------------------------------------|---------|
|`BACKUP`| Boolean on whether to perform backups. | `true` |
|`CONSUL_ARGS`| Arguments to pass into the consul agent.  For example `-config-dir=/consul/config  -config-dir=/consul/secrets`. | required |
|`S3_URL`| The s3 location to save the backups. For example `s3://my-bucket/consul-backups/` | required if `BACKUP=true` |
|`SLEEP_DURATION`| Duration between backups (in seconds). | `1800` |
|`RESTORE_FILE`| Full s3 path of a file to restore.  This will be performed initially before any backups occur. Example `s3://my-bucket/consul-backups/consul-20180215.122934.snap`. | optional |

### Volume Mounts

One or more Consul configuration files must be mounted into this container and the path set using the `CONSUL_ARGS` environment variable.

See [Usage](#usage) above for examples.
