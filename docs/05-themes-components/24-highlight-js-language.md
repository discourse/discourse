---
title: Install a new language for Highlight.JS via a theme component
short_title: Highlight.JS language
id: highlight-js-language

---
I've just added a hook to our HighlightJS code so now you can use the plugin API to add a custom language for Highlight.JS. 

Example (using the beancount language definition): 
```js
const beancountLang = function(e){var c="[A-Z][A-Za-z0-9-]*",a="[0-9]{4}[-|/][0-9]{2}[-|/][0-9]{2}",b="(balance|commodity|custom|document|event|note|open|pad|price|query)",t={cN:"literal",b:/([\-|\+]?)([\d]+[\.]?[\d]*)/,r:0},n={cN:"string",b:'"',e:'"',r:0,c:[e.BE]},s={cN:"name",b:"\\{",e:"\\}",c:[{cN:"literal",b:a},t,n,{cN:"subst",b:"[A-Z][A-Z0-9'._-]{0,22}[A-Z0-9]"}]};return{aliases:["beancount","bean","ledger"],c:[{cN:"built_in",b:"^(include|option|plugin|popmeta|poptag|pushmeta|pushtag)",r:0},{b:"^"+a+"\\s+"+b,rB:!0,r:10,c:[{cN:"type",b:a,e:/\s+/,eE:!0},{cN:"keyword",b:b}]},{b:"^"+a+"\\s+.\\s",rB:!0,r:10,c:[{cN:"type",b:a,e:"\\s+",eE:!0},{cN:"variable",b:".",endsParent:!0}]},e.C(";","$"),{cN:"meta",b:/^\s{2,}[a-z][A-Za-z0-9\-_]+:/},s,{cN:"name",b:"@"},{cN:"type",b:c+":",r:0,c:[{cN:"subst",b:c+"(:"+c+")?"}]},{cN:"section",b:/^\*\s+?.*/},{cN:"link",b:/\^[A-Za-z0-9\-_\/.]+/},{cN:["emphasis"],b:/#[A-Za-z0-9\-_\/.]+/},n,t]}}
api.registerHighlightJSLanguage("beancount", beancountLang);
```

Official theme components which use this API:

- https://github.com/discourse/discourse-highlightjs-glimmer

- https://github.com/discourse/discourse-highlightjs-structured-text
