Discourse.Dialect.addPreProcessor(function(text) {
  text = Discourse.BlockedUrls.blockUrl(text);
  return Discourse.CensoredWords.censor(text);
});
