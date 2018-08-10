 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
hljs.registerLanguage("roboconf",function(a){var e="[a-zA-Z-_][^\\n{]+\\{",n={cN:"attribute",b:/[a-zA-Z-_]+/,e:/\s*:/,eE:!0,starts:{e:";",r:0,c:[{cN:"variable",b:/\.[a-zA-Z-_]+/},{cN:"keyword",b:/\(optional\)/}]}};return{aliases:["graph","instances"],cI:!0,k:"import",c:[{b:"^facet "+e,e:"}",k:"facet",c:[n,a.HCM]},{b:"^\\s*instance of "+e,e:"}",k:"name count channels instance-data instance-state instance of",i:/\S/,c:["self",n,a.HCM]},{b:"^"+e,e:"}",c:[n,a.HCM]},a.HCM]}});
//@license-end
