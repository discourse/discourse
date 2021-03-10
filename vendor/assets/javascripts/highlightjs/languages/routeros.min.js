hljs.registerLanguage("routeros",(()=>{"use strict";return e=>{
const r="foreach do while for if from to step else on-error and or not in",n="true false yes no nothing nil null",i={
className:"variable",variants:[{begin:/\$[\w\d#@][\w\d_]*/},{begin:/\$\{(.*?)\}/
}]},s={className:"string",begin:/"/,end:/"/,contains:[e.BACKSLASH_ESCAPE,i,{
className:"variable",begin:/\$\(/,end:/\)/,contains:[e.BACKSLASH_ESCAPE]}]},t={
className:"string",begin:/'/,end:/'/};return{name:"Microtik RouterOS script",
aliases:["mikrotik"],case_insensitive:!0,keywords:{$pattern:/:?[\w-]+/,
literal:n,
keyword:r+" :"+r.split(" ").join(" :")+" :"+"global local beep delay put len typeof pick log time set find environment terminal error execute parse resolve toarray tobool toid toip toip6 tonum tostr totime".split(" ").join(" :")
},contains:[{variants:[{begin:/\/\*/,end:/\*\//},{begin:/\/\//,end:/$/},{
begin:/<\//,end:/>/}],illegal:/./},e.COMMENT("^#","$"),s,t,i,{
begin:/[\w-]+=([^\s{}[\]()>]+)/,relevance:0,returnBegin:!0,contains:[{
className:"attribute",begin:/[^=]+/},{begin:/=/,endsWithParent:!0,relevance:0,
contains:[s,t,i,{className:"literal",begin:"\\b("+n.split(" ").join("|")+")\\b"
},{begin:/("[^"]*"|[^\s{}[\]]+)/}]}]},{className:"number",begin:/\*[0-9a-fA-F]+/
},{
begin:"\\b(add|remove|enable|disable|set|get|print|export|edit|find|run|debug|error|info|warning)([\\s[(\\]|])",
returnBegin:!0,contains:[{className:"builtin-name",begin:/\w+/}]},{
className:"built_in",variants:[{
begin:"(\\.\\./|/|\\s)((traffic-flow|traffic-generator|firewall|scheduler|aaa|accounting|address-list|address|align|area|bandwidth-server|bfd|bgp|bridge|client|clock|community|config|connection|console|customer|default|dhcp-client|dhcp-server|discovery|dns|e-mail|ethernet|filter|firmware|gps|graphing|group|hardware|health|hotspot|identity|igmp-proxy|incoming|instance|interface|ip|ipsec|ipv6|irq|l2tp-server|lcd|ldp|logging|mac-server|mac-winbox|mangle|manual|mirror|mme|mpls|nat|nd|neighbor|network|note|ntp|ospf|ospf-v3|ovpn-server|page|peer|pim|ping|policy|pool|port|ppp|pppoe-client|pptp-server|prefix|profile|proposal|proxy|queue|radius|resource|rip|ripng|route|routing|screen|script|security-profiles|server|service|service-port|settings|shares|smb|sms|sniffer|snmp|snooper|socks|sstp-server|system|tool|tracking|type|upgrade|upnp|user-manager|users|user|vlan|secret|vrrp|watchdog|web-access|wireless|pptp|pppoe|lan|wan|layer7-protocol|lease|simple|raw);?\\s)+"
},{begin:/\.\./,relevance:0}]}]}}})());