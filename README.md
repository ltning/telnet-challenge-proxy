# Challenging Telnet-proxy

In order to protect my BBS nodes - which run on rather old hardware - from abuse, I created this Nginx-and-Lua-based stream proxy for Telnet connections. It will present the user with a (very) simple mathematical challenge.

## My BBS
Take a look at http://floppy.museum/bbs.htm for details. At the moment, it's running on Synchronet for OS/2 and DOS; other nodes and different flavors may be added in the future.

## Assumptions
This configuration assumes that the `nginx` package is installed on FreeBSD, and that it is compiled with Lua and Lua Stream modules.

More information about these can be found at
- https://github.com/openresty/lua-nginx-module
- https://github.com/openresty/stream-lua-nginx-module

## Running on other platforms
I've made every attempt to make sure the `nginx.conf` itself and the Lua code in `bbs_math.lua` are reasonably well documented. Making this work on other platforms than FreeBSD should be a simple matter of modifying some paths here and there - as long as the required nginx modules are installed.

## Running in docker
No, I have no idea how you can run this in docker or whatnot. I'm happy to take PRs though. :)
