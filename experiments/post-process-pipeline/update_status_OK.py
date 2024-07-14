#!/usr/bin/env python3

low_overhead_projects = """2captcha-2captcha-java
3redronin-mu-server
andylamp-BPlusTree
apache-commons-codec
AuthorizeNet-sample-code-java
Barteks2x-173generator
BingAds-BingAds-Java-SDK
bouncestorage-chaos-http-proxy
Cantara-Java-Auto-Update
ChannelApe-shopify-sdk
ctrl-alt-dev-tps-parse
davidmoten-rxjava-extras
didi-benchmark-thrift
f4b6a3-tsid-creator
f4b6a3-uuid-creator
ganskef-LittleProxy-mitm
JavaMoney-jsr354-ri-bp
jlinn-quartz-redis-jobstore
jprante-elasticsearch-transport-websocket
LatencyUtils-LatencyUtils
leonhad-paradoxdriver
LiveRamp-HyperMinHash-java
lucaspouzac-contiperf
mduerig-json-jerk
MottoX-TAOMP
msigwart-fakeload
nothingax-micro-DB
opentimestamps-java-opentimestamps
peter-lawrey-admin-Chronicle-Ticker
qubole-qds-sdk-java
resourcepool-ssdp-client
rnorth-duct-tape
seaswalker-netty-wheel
smallnest-fastjson-jaxrs-json-provider
spdx-Spdx-Java-Library
spinscale-elasticsearch-graphite-plugin
ThoughtWire-hazelcast-locks
tomwhite-set-game
upyun-java-sdk
urbanairship-java-library
victor-porcar-delayed-batch-executor
xingePush-xinge-api-java"""

lines = []
with open('timing-2-28.csv', 'r') as f:
	for line in f.readlines():
		if line.split(',')[0] in low_overhead_projects:
			lines.append(line.replace(',OK,', ',low MOP overhead,'))
		else:
			lines.append(line)

with open('timing-2-28-fixed.csv', 'w') as f:
	f.writelines(lines)
