Discourse.Dialect.addPreProcessor(function(text) {
  return Discourse.CensoredWords.censor(text);
});
