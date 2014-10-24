hljs.registerLanguage('clojure-repl', function(hljs) {
  return {
    contains: [
      {
        className: 'prompt',
        begin: /^([\w.-]+|\s*#_)=>/,
        starts: {
          end: /$/,
          subLanguage: 'clojure', subLanguageMode: 'continuous'
        }
      }
    ]
  }
});
