# StatsD

A very simple client to format and send metrics to a StatsD server.

### Installation

    gem install statsd

### Client
In your client code:

    require 'rubygems'
    require 'statsd'
    STATSD = Statsd::Client.new(:host => 'localhost', :port => 8125)

    STATSD.increment('some_counter') # basic incrementing
    STATSD.increment('system.nested_counter', 0.1) # incrementing with sampling (10%)

    STATSD.decrement(:some_other_counter) # basic decrememting using a symbol
    STATSD.decrement('system.nested_counter', 0.1) # decrementing with sampling (10%)

    STATSD.timing('some_job_time', 20) # reporting job that took 20ms
    STATSD.timing('some_job_time', 20, 0.05) # reporting job that took 20ms with sampling (5% sampling)

There is an option for reduced DNS lookups, you can specify an additional
constructor option `:resolve_always` and set it to `false`. By default, the
client will always resolve the address unless `host` is set to 'localhost' or
'127.0.0.1'.

    require 'rubygems'
    require 'statsd'

    STATSD = Statsd::Client.new(:host => 'specialstats.host.example',
                                :port => '8125',
                                :resolve_always => false)

    STATSD.increment('some_counter') # basic incrementing

#### Note about thread-safety

Since class variables and instance variables are not thread-safe on
initialization, there is a potential for multiple UDP sockets being opened upon
if you are using a truly multithreaded ruby, i.e. JRuby. Make sure to take that
in to account when initializing this library.

Guts
----

* [UDP][udp]
  Client libraries use UDP to send information to the StatsD daemon.

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


Inspiration
-----------
[Etsy's][etsy] [blog post][blog post].

StatsD was inspired (heavily) by the project (of the same name) at Flickr. Here's a post where Cal Henderson described it in depth:
[Counting and timing](http://code.flickr.com/blog/2008/10/27/counting-timing/). Cal re-released the code recently: [Perl StatsD](https://github.com/iamcal/Flickr-StatsD)


[graphite]: http://graphite.wikidot.com
[etsy]: http://www.etsy.com
[blog post]: http://codeascraft.etsy.com/2011/02/15/measure-anything-measure-everything/
[udp]: http://enwp.org/udp
