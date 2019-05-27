Ember.Test.registerHelper("setTextareaSelection", function(
  app,
  textarea,
  selectionStart,
  selectionEnd
) {
  textarea.selectionStart = selectionStart;
  textarea.selectionEnd = selectionEnd;
});

Ember.Test.registerHelper("getTextareaSelection", function(app, textarea) {
  var start = textarea.selectionStart;
  var end = textarea.selectionEnd;
  return [start, end - start];
});
