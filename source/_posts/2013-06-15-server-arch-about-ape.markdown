---
layout: post
title: "猿题库服务端实践"
date: 2013-06-15 21:41
comments: true
categories: 开发
---
[猿题库](http://yuantiku.com)是[粉笔网](http://fenbi.com)旗下的智能在线题库，目前已经发布了[公务员行测](http://yuantiku.com/xingce)、[公务员申论](http://yuantiku.com/shenlun)和[国家司法考试](http://yuantiku.com/sikao)三门课程。近期会发布考研政治和一级建造师。

## 系统部署结构

{% img /images/archofyuantikudotcom.png %}

### Nginx
我们在两台机器上部署了配置完全一样的Nginx，使用keepalived来达到High Availability的目的。目前并没有针对Nginx做负载均衡，访问量没那么大。

Nginx会接管所有的静态资源请求。最开始Nginx是直接从NFS上读取这些文件。使用NFS是为了保证冷备的Nginx也能随时读取到静态文件。后来我们觉得仅仅因为静态文件而使用使用NFS必要性不高且多了一个故障点（我们确实遇到了NFS挂载点丢失的现象），就逐渐去掉对NFS的依赖（目前还没有完全去掉）。Nginx同时会将动态请求代理给后端的Tomcat。

### Tomcat
我们的全部在线逻辑都运行在Tomcat中，包括Web页面以及对iPhone和Android客户端提供的REST Api。目前由于不同课程的升级频率、访问量都不太一样，我们为每个课程部署独立的Tomcat。目前我们已经部署了6个Tomcat实例，提供的服务分别是猿题库基础公共服务（用户信息等）、公务员行测和申论、国家司法考试。每个服务都部署2个实例一方面是为了保证能平滑的对服务进行升级，另外一方面也是做负载均衡。

但这种为每个课程独立部署Tomcat的行为已经难以为继了，我们很快就会再上2个课程，而今年下半年会有更多的课程上线，这样部署方式会导致我们有近百个Tomcat服务，运维成本会急剧提高，因此我们接下来会将新上线的多个课程部署在同一个的Tomcat实例中。原有已上线的课程也会逐渐加入到这类实例中（需要做一些代码上的调整，所以原有课程不能立即部署进来）。最终目标，我们希望任一Tomcat都能提供完全相同的服务以保证系统更容易维护和扩展。

### MySQL和Redis
目前我们将数据存储在MySQL和Redis上。不同类型的数据存储在不同的服务上，例如用户数据以及各种练习报告都存储在MySQL中，而做题过程中的答案数据（数量巨大，单个记录数据量极小，适合使用list存储）则保存在Redis上。

当前阶段我们更看重数据的Reliability，其次才会考虑整个服务的Availability，服务偶尔down一下还OK，但数据永久性丢失则不可接受。我们将MySQL和Redis配置为master-slave结构，同时定时从slave上dump完整的数据，并每天对数据做**跨机房备份**（实际上就是将机房的数据rsync到办公室的的Hadoop机群上）。另外，服务器都做了RAID（1和5）。

而由于当前服务器压力并不大，且我们对MySQL存在read after write的需求，因此也就没有对MySQL的slave进行读取。

### Hadoop
高峰阶段，用户每天在猿题库上做的题目数超过百万，但猿题库整体的数据并不大，照理说是不需要赶时髦上Hadoop的（实际上也完全不时髦了）。但考虑到发展速度以及对Hadoop经验积累的需求，我们还是在办公室用一些台式机器搭建了一个Hadoop机群，主要用来备份线上数据和存储各种log，也做一些数据分析工作。当前我们直接将log输出到文件然后导入到HDFS上，接下来会调研[Scribe](https://github.com/facebook/scribe)。我们使用Hive来对log进行分析以帮助公司做决策。在办公室用台式机搭建机群主要是节约成本（机柜、服务器、带宽）。

## 下一步工作
接下来的重点工作是提高系统的Availability和Scalability。MySQL将会配置为master-master模式并通过HAProxy实现Auto-Failover，这样即使一台MySQL挂掉了也不会导致服务不可用。

另外还需要将Redis中存储的数据保存到MySQL中，将Redis仅仅作为缓存服务而不做为数据存储服务。这么做一方面是因为Redis成熟度还是不如MySQL，挂掉的可能性远高于MySQL，另外一方面是希望进一步简化系统结构、降低运维成本。

应用服务（逻辑）开发方面，主要是增加对数据切分的支持来提高扩展性。另外会将Tomcat中数据管理部分逻辑拿出来做成独立服务，原因是这部分逻辑很固定不会变动，同时又有通过后台系统对数据进行修改和复杂的数据合法性校验的需求。

## 团队及工作方式
目前我们服务器团队共5个人，3人来自有道，1人来自新浪微博，还有1个应届毕业生。团队之前的经验包括分布式系统、并行计算、数据库系统、搜索引擎等。我们团队使用[Git和Gerrit](https://code.google.com/p/gerrit/)来管理和Review代码，使用[Redmine](http://redmine.org)做项目管理和Bug管理，使用[Moin Wiki](http://moinmo.in/)做文档管理。