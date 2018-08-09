 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
hljs.registerLanguage("subunit",function(s){var r={cN:"string",b:"\\[\n(multipart)?",e:"\\]\n"},t={cN:"string",b:"\\d{4}-\\d{2}-\\d{2}(\\s+)\\d{2}:\\d{2}:\\d{2}.\\d+Z"},e={cN:"string",b:"(\\+|-)\\d+"},c={cN:"keyword",r:10,v:[{b:"^(test|testing|success|successful|failure|error|skip|xfail|uxsuccess)(:?)\\s+(test)?"},{b:"^progress(:?)(\\s+)?(pop|push)?"},{b:"^tags:"},{b:"^time:"}]};return{cI:!0,c:[r,t,e,c]}});
//@license-end
