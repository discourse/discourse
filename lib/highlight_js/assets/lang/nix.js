 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
hljs.registerLanguage("nix",function(e){var r={keyword:"rec with let in inherit assert if else then",literal:"true false or and null",built_in:"import abort baseNameOf dirOf isNull builtins map removeAttrs throw toString derivation"},t={cN:"subst",b:/\$\{/,e:/}/,k:r},i={b:/[a-zA-Z0-9-_]+(\s*=)/,rB:!0,r:0,c:[{cN:"attr",b:/\S+/}]},s={cN:"string",c:[t],v:[{b:"''",e:"''"},{b:'"',e:'"'}]},a=[e.NM,e.HCM,e.CBCM,s,i];return t.c=a,{aliases:["nixos"],k:r,c:a}});
//@license-end
