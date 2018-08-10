 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
hljs.registerLanguage("awk",function(e){var r={cN:"variable",v:[{b:/\$[\w\d#@][\w\d_]*/},{b:/\$\{(.*?)}/}]},b="BEGIN END if else while do for in break continue delete next nextfile function func exit|10",n={cN:"string",c:[e.BE],v:[{b:/(u|b)?r?'''/,e:/'''/,r:10},{b:/(u|b)?r?"""/,e:/"""/,r:10},{b:/(u|r|ur)'/,e:/'/,r:10},{b:/(u|r|ur)"/,e:/"/,r:10},{b:/(b|br)'/,e:/'/},{b:/(b|br)"/,e:/"/},e.ASM,e.QSM]};return{k:{keyword:b},c:[r,n,e.RM,e.HCM,e.NM]}});
//@license-end
