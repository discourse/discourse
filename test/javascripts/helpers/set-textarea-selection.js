Ember.Test.registerHelper("setTextareaSelection", function(
  app,
  textarea,
  selectionStart,
  selectionEnd
) {
  textarea.selectionStart = selectionStart;
  textarea.selectionEnd = selectionEnd;
});
