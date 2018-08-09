 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
hljs.registerLanguage("taggerscript",function(e){var c={cN:"comment",b:/\$noop\(/,e:/\)/,c:[{b:/\(/,e:/\)/,c:["self",{b:/\\./}]}],r:10},r={cN:"keyword",b:/\$(?!noop)[a-zA-Z][_a-zA-Z0-9]*/,e:/\(/,eE:!0},a={cN:"variable",b:/%[_a-zA-Z0-9:]*/,e:"%"},b={cN:"symbol",b:/\\./};return{c:[c,r,a,b]}});
//@license-end
