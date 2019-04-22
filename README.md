# ircb
## non-overengineered awk irc bot
`ircb` is an awk irc bot. It accepts raw data from IRC via stdin, and outputs IRC commands to stdout. It is completely `nawk`-compatible; you will find no GNU/awk-exclusive functionality.

Sample invocation using a FIFO `in` might look like:
```
netcat my.irc.network 6667 <in | awk -f ircb.awk >in
```
This setup is extremely versatile; run the data streams through as many pipes and `sed` and `grep` commands as you want.

## modules
`ircb` supports a host of modules, most of which you don't need. In fact, maintainers are actively encouraged to dispose of any modules they do not need.
`modules/boot.awk` is considered the only "necessary" module. Anything else is optional.

Including modules can be done using awk's `-f` option:
```
netcat my.irc.network 6667 <in | awk -f ircb.awk -f modules/boot.awk -f modules/tell.awk >in
```
For information on module usage, check the actual `.awk` file.

## configuration
**How not to configure ircb:** open each individual module file and modify the variables in the `BEGIN` block.  
**How to configure ircb:** write a `config.awk` with a `BEGIN` block where you declare your configuration variables. Include this after every other module using `-f`

## i18n
Write a `lang.awk` file where you overwrite response templates. Include this after all other modules. For example:
```
# es.awk
BEGIN {
	dbinterface_Template["conflict"] = "[%s] Error fatal: opciones conflictivas `%s` y `%s` especificado."
}
```

## tips
irc logger: `/usr/bin/tee`  
configuration variables are denoted with `###`.  
ircd weirdness is documented using `##`
