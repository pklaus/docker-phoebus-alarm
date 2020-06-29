# docker-phoebus-alarm

This repository hosts the Dockerfile used to build two Docker images
published on the Docker Hub:

* [pklaus/phoebus-alarm-server][] and
* [pklaus/phoebus-alarm-logger][].

They package the [latest (nightly) release][nightly] of the Phoebus products
**alarm-server** and **alarm-logger**.

The images are both deriving `FROM openjdk:16-slim-buster`.

## Usage

First of all, please have a look at the official documentation:

* Phoebus' [documentation][doc-phoebus], specifically:
    * [Service alarm-server][doc-alarm-server]
    * [Service alarm-logger][doc-alarm-logger]
    * [Phoebus alarm UI][doc-alarm-ui]
* README Files in in Phoebus' source code:
    * [General Alarm Application README][readme app/alarm]
    * [Alarm-Server Readme][readme services/alarm-server]
    * [Alarm-Logger Readme][readme services/alarm-logger]
* Default properties in Phoebus' source code:
    * [alarm\_logger.properties][]
* A presentation given by Kay Kasemir and Kunal Shroff
  at the June 2019 EPICS Meeting:
    * [Phoebus Alarm System: Alarm Server][phoebus-alarm-presentation]

### alarm-server

**CLI / Docker `ENTRYPOINT`**

The images have their respective Java application configured as
`ENTRYPOINT`, so any argument provided will directly go to the
`alarm-server` or `alarm-logger` respectively.

For example, use the `-h` flag to get the CLI help:

```
$ docker run --rm -it pklaus/phoebus-alarm-server -h
 _______  _        _______  _______  _______    _______  _______  _______           _______  _______
(  ___  )( \      (  ___  )(  ____ )(       )  (  ____ \(  ____ \(  ____ )|\     /|(  ____ \(  ____ )
| (   ) || (      | (   ) || (    )|| () () |  | (    \/| (    \/| (    )|| )   ( || (    \/| (    )|
| (___) || |      | (___) || (____)|| || || |  | (_____ | (__    | (____)|| |   | || (__    | (____)|
|  ___  || |      |  ___  ||     __)| |(_)| |  (_____  )|  __)   |     __)( (   ) )|  __)   |     __)
| (   ) || |      | (   ) || (\ (   | |   | |        ) || (      | (\ (    \ \_/ / | (      | (\ (
| )   ( || (____/\| )   ( || ) \ \__| )   ( |  /\____) || (____/\| ) \ \__  \   /  | (____/\| ) \ \__
|/     \|(_______/|/     \||/   \__/|/     \|  \_______)(_______/|/   \__/   \_/   (_______/|/   \__/

Command-line arguments:

-help                          - This text
-server    localhost:9092      - Kafka server with port number
-config    Accelerator         - Alarm configuration
-settings  settings.{xml,ini}  - Import preferences (PV connectivity) from property format file
-noshell                       - Disable the command shell for running without a terminal
-export    config.xml          - Export alarm configuration to file
-import    config.xml          - Import alarm configruation from file
-logging   logging.properties  - Load log settings
```

As can be seen from the CLI signature, the alarm-server has three options which have
filenames as arguments: `-settings` as well as `-import` and `-export`.
It's best to mount the settings from the host computer when creating the container.

**Settings**

The settings.ini file contains custom preference settings.
Please have a look at Phoebus' general info about the [preferences][Phoebus preferences]
for info on how to put together such a settings.ini file.

A list of preferences used by the alarm-server is stated below.
Preferences that seem irrelevant (or less important) are stated in brackets:

* [alarm][alarm preferences] *most important!*
* [email][email preferences] *important if the alarm server should send emails*
* [pv.ca][pv.ca preferences] *relevant if CA needs configuration (like custom CA address list)*
* irrelevant or less important: ([pv][pv preferences] | [pv.formula][pv.formula preferences] |
  [pv.mqtt][pv.mqtt preferences] | [framework.autocomplete][framework.autocomplete preferences] |
  [framework.workbench][framework.workbench preferences])

As an example, the resulting settings.ini might look like:

```ini
org.phoebus.applications.alarm/server=localhost:9092
org.phoebus.applications.alarm/config_name=YourSystem
org.phoebus.applications.alarm/config_names=YourSystem, Demo
org.phoebus.applications.alarm/connection_timeout=15
org.phoebus.applications.alarm/automated_email_sender=Alarm Notifier <alarm_server@example.org>

org.phoebus.email/mailhost=smtp.bnl.gov
org.phoebus.email/mailport=25
org.phoebus.email/username=
org.phoebus.email/password=
```

**Kafka**

alarm-server uses a Kafka instance to exchange data.
Check the [General Alarm Application README][readme app/alarm]
and and [src: app/alarm/examples][] for help and scripts
to configure the Kafka instance.

[src: app/alarm/examples/create\_alarm\_topic.sh][] lists the commands
to create the required Kafka topics for a given alarm setup (here: `Accelerator`)
and the configuration for the topics. In the container world, this translates to:

1. Start a container to run a Kafka shell (where `kafka` is the hostname of a Kafka server):
```
docker run \
  --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e KAFKA=kafka \
  --network your_kafka_net \
  -w /opt/kafka_2.12-2.5.0/bin \
  wurstmeister/kafka:2.12-2.5.0 /bin/bash
```
2. enter:
```bash
TOPIC=Accelerator


kafka-topics.sh --bootstrap-server $KAFKA:9092 \
  --create --replication-factor 1 --partitions 1 \
  --topic $TOPIC

config="cleanup.policy=compact,"
config+="segment.ms=10000,"
config+="min.cleanable.dirty.ratio=0.01,"
config+="min.compaction.lag.ms=1000"

kafka-configs.sh --bootstrap-server $KAFKA:9092 \
  --entity-type topics --alter \
  --entity-name $TOPIC --add-config $config

config="cleanup.policy=delete,"
config+="segment.ms=10000,"
config+="min.cleanable.dirty.ratio=0.01,"
config+="min.compaction.lag.ms=1000,"
config+="retention.ms=20000,"
config+="delete.retention.ms=1000,"
config+="file.delete.delay.ms=1000"

for d_topic in ${TOPIC}Command ${TOPIC}Talk
do

  kafka-topics.sh  --bootstrap-server $KAFKA:9092 \
    --create --replication-factor 1 --partitions 1 \
    --topic $d_topic

  kafka-configs.sh --bootstrap-server $KAFKA:9092 \
    --entity-type topics --alter \
    --entity-name $d_topic --add-config $config

done
```

#### alarm-logger

```
$ docker run --rm -it pklaus/phoebus-alarm-logger -h

  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::        (v2.1.5.RELEASE)

2020-06-29 11:07:57.445  INFO 1 --- [           [...]
                                                [...]
2020-06-29 11:07:58.464  INFO 1 --- [           [...]

 _______  _        _______  _______  _______    _        _______  _______  _______  _______  _______
(  ___  )( \      (  ___  )(  ____ )(       )  ( \      (  ___  )(  ____ \(  ____ \(  ____ \(  ____ )
| (   ) || (      | (   ) || (    )|| () () |  | (      | (   ) || (    \/| (    \/| (    \/| (    )|
| (___) || |      | (___) || (____)|| || || |  | |      | |   | || |      | |      | (__    | (____)|
|  ___  || |      |  ___  ||     __)| |(_)| |  | |      | |   | || | ____ | | ____ |  __)   |     __)
| (   ) || |      | (   ) || (\ (   | |   | |  | |      | |   | || | \_  )| | \_  )| (      | (\ (
| )   ( || (____/\| )   ( || ) \ \__| )   ( |  | (____/\| (___) || (___) || (___) || (____/\| ) \ \__
|/     \|(_______/|/     \||/   \__/|/     \|  (_______/(_______)(_______)(_______)(_______/|/   \__/

Command-line arguments:

-help                                    - This text
-noshell                                 - Disable the command shell for running without a terminal
-topics   Accelerator                    - Alarm topics to be logged, they can be defined as a comma separated list
-es_host  localhost                      - elastic server host
-es_port  9200                           - elastic server port
-es_sniff  false                         - elastic server sniff feature
-bootstrap.servers localhost:9092        - Kafka server address
-properties /opt/alarm_logger.properties - Properties file to be used (instead of command line arguments)
-date_span_units M                       - Date units for the time based index to span.
-date_span_value 1                       - Date value for the time based index to span.
-logging logging.properties              - Load log settings
```

Most of the settings of the alarm-logger can be set directly from the command line.
The `-properties` argument allows to alternatively provide them via a properties file.

**Settings**

Again, the list of preferences used by the alarm-logger is stated below.

* [alarm][alarm preferences] *most important*
* irrelevant or less important: ([framework.autocomplete][framework.autocomplete preferences] |
  [framework.workbench][framework.workbench preferences])

**Elasticsearch**

alarm-logger uses an elasticsearch instance to log to.
Check [src: services/alarm-logger/startup][] for the scripts `create_alarm_index.sh`
and `create_alarm_template.sh` to configure the elasticsearch instance.
They are part of the alarm-logger Docker image and can be executed after first
starting like this:

```
docker run\
  --rm -it \
  -e es_host=elasticsearch \
  -e es_port=9200 \
  --entrypoint /bin/bash \
  --network your_elasticsearch_net \
  pklaus/phoebus-alarm-logger \
  -c "./create_alarm_index.sh accelerator && ./create_alarm_template.sh"
```

## References

* Prior work by @carneirofc (Cláudio Ferreira Carneiro):
  <https://github.com/lnls-sirius/cons-phoebus-alarm>

[pklaus/phoebus-alarm-server]: https://hub.docker.com/r/pklaus/phoebus-alarm-server
[pklaus/phoebus-alarm-logger]: https://hub.docker.com/r/pklaus/phoebus-alarm-logger
[nightly]: https://controlssoftware.sns.ornl.gov/css_phoebus/nightly/
[doc-phoebus]: https://control-system-studio.readthedocs.io
[doc-alarm-server]: https://control-system-studio.readthedocs.io/en/latest/services/alarm-server/doc/index.html
[doc-alarm-logger]: https://control-system-studio.readthedocs.io/en/latest/services/alarm-logger/doc/index.html
[doc-alarm-ui]: https://control-system-studio.readthedocs.io/en/latest/app/alarm/ui/doc/index.html
[readme app/alarm]: https://github.com/ControlSystemStudio/phoebus/tree/master/app/alarm#alarm-system
[readme services/alarm-server]: https://github.com/ControlSystemStudio/phoebus/tree/master/services/alarm-server#alarm-server
[readme services/alarm-logger]: https://github.com/ControlSystemStudio/phoebus/tree/master/services/alarm-logger#alarm-logging
[phoebus-alarm-presentation]: https://indico.cern.ch/event/766611/contributions/3438293/attachments/1854259/3045083/Phoebus_Alarm_System.pdf
[alarm preferences]: https://control-system-studio.readthedocs.io/en/latest/preference_properties.html#alarm
[email preferences]: https://control-system-studio.readthedocs.io/en/latest/preference_properties.html#email
[pv preferences]: https://control-system-studio.readthedocs.io/en/latest/preference_properties.html#pv
[pv.ca preferences]: https://control-system-studio.readthedocs.io/en/latest/preference_properties.html#pv-ca
[pv.formula preferences]: https://control-system-studio.readthedocs.io/en/latest/preference_properties.html#pv-formula
[pv.mqtt preferences]: https://control-system-studio.readthedocs.io/en/latest/preference_properties.html#pv-mqtt
[framework.autocomplete preferences]: https://control-system-studio.readthedocs.io/en/latest/preference_properties.html#framework-autocomplete
[framework.workbench preferences]: https://control-system-studio.readthedocs.io/en/latest/preference_properties.html#framework-workbench
[Phoebus preferences]: https://control-system-studio.readthedocs.io/en/latest/preferences.html
[alarm\_logger.properties]: https://github.com/ControlSystemStudio/phoebus/blob/master/services/alarm-logger/src/main/resources/alarm_logger.properties
[src: services/alarm-logger/startup]: https://github.com/ControlSystemStudio/phoebus/tree/master/services/alarm-logger/startup
[src: app/alarm/examples]: https://github.com/ControlSystemStudio/phoebus/tree/master/app/alarm/examples
[src: app/alarm/examples/create\_alarm\_topic.sh]: https://github.com/ControlSystemStudio/phoebus/blob/master/app/alarm/examples/create_alarm_topics.sh
