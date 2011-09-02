# StatsD

A network daemon for aggregating statistics (counters and timers), rolling them up, then sending them to [graphite][graphite].


### Installation

    gem install statsd

### Configuration

Create config.yml to your liking. There are 2 flush protocols: graphite and mongo. The former simply sends to carbon every flush interval. The latter flushes to MongoDB capped collections for 10s and 1min intervals.

Example config.yml
    ---
    bind: 127.0.0.1
    port: 8125

    # Flush interval should be your finest retention in seconds
    flush_interval: 10

    # Graphite
    graphite_host: localhost
    graphite_port: 2003



### Server
Run the server:

Flush to Graphite (default):
    statsd -c config.yml

### Client
In your client code:

    require 'rubygems'
    require 'statsd'
    STATSD = Statsd::Client.new('localhost',8125)

    STATSD.increment('some_counter') # basic incrementing
    STATSD.increment('system.nested_counter', 0.1) # incrementing with sampling (10%)

    STATSD.decrement(:some_other_counter) # basic decrememting using a symbol
    STATSD.decrement('system.nested_counter', 0.1) # decrementing with sampling (10%)

    STATSD.timing('some_job_time', 20) # reporting job that took 20ms
    STATSD.timing('some_job_time', 20, 0.05) # reporting job that took 20ms with sampling (5% sampling)

Concepts
--------

* *buckets*
  Each stat is in it's own "bucket". They are not predefined anywhere. Buckets can be named anything that will translate to Graphite (periods make folders, etc)

* *values*
  Each stat will have a value. How it is interpreted depends on modifiers

* *flush*
  After the flush interval timeout (default 10 seconds), stats are munged and sent over to Graphite.

Counting
--------

    gorets:1|c

This is a simple counter. Add 1 to the "gorets" bucket. It stays in memory until the flush interval.


Timing
------

    glork:320|ms

The glork took 320ms to complete this time. StatsD figures out 90th percentile, average (mean), lower and upper bounds for the flush interval.

Sampling
--------

    gorets:1|c|@0.1

Tells StatsD that this counter is being sent sampled ever 1/10th of the time.


Guts
----

* [UDP][udp]
  Client libraries use UDP to send information to the StatsD daemon.

* [EventMachine][eventmachine]
* [Graphite][graphite]


Graphite
--------

Graphite uses "schemas" to define the different round robin datasets it houses (analogous to RRAs in rrdtool):

    [stats]
    priority = 110
    pattern = ^stats\..*
    retentions = 10:2160,60:10080,600:262974

That translates to:

* 6 hours of 10 second data (what we consider "near-realtime")
* 1 week of 1 minute data
* 5 years of 10 minute data

This has been a good tradeoff so far between size-of-file (round robin databases are fixed size) and data we care about. Each "stats" database is about 3.2 megs with these retentions.


MongoDB
-------------

Statd::Mongo will flush and aggregate data to a MongoDB. The average record size is 152 bytes. We use capped collections for the transient data and regular collections for long-term storage.

Inspiration
-----------
[Etsy's][etsy] [blog post][blog post].

StatsD was inspired (heavily) by the project (of the same name) at Flickr. Here's a post where Cal Henderson described it in depth:
[Counting and timing](http://code.flickr.com/blog/2008/10/27/counting-timing/). Cal re-released the code recently: [Perl StatsD](https://github.com/iamcal/Flickr-StatsD)


[graphite]: http://graphite.wikidot.com
[etsy]: http://www.etsy.com
[blog post]: http://codeascraft.etsy.com/2011/02/15/measure-anything-measure-everything/
[udp]: http://enwp.org/udp
[eventmachine]: http://rubyeventmachine.com/
[mongodb]: http://www.mongodb.org/
