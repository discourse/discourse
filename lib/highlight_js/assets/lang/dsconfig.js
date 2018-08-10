 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
hljs.registerLanguage("dsconfig",function(e){var i={cN:"string",b:/"/,e:/"/},r={cN:"string",b:/'/,e:/'/},s={cN:"string",b:"[\\w-?]+:\\w+",e:"\\W",r:0},t={cN:"string",b:"\\w+-?\\w+",e:"\\W",r:0};return{k:"dsconfig",c:[{cN:"keyword",b:"^dsconfig",e:"\\s",eE:!0,r:10},{cN:"built_in",b:"(list|create|get|set|delete)-(\\w+)",e:"\\s",eE:!0,i:"!@#$%^&*()",r:10},{cN:"built_in",b:"--(\\w+)",e:"\\s",eE:!0},i,r,s,t,e.HCM]}});
//@license-end
