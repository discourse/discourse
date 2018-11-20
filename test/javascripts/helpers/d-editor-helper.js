Ember.Test.registerAsyncHelper("formatTextWithSelection", function(
  app,
  text,
  [start, len]
) {
  return [
    '"',
    text.substr(0, start),
    "<",
    text.substr(start, len),
    ">",
    text.substr(start + len),
    '"'
  ].join("");
});
