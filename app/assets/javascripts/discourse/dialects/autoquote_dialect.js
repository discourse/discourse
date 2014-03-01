/**
  If a line contains a single quote, convert it to a blockquote. For example:

  "My fake plants died because I did not pretend to water them."

  Would be:

  <blockquote>My fake plants died because I did not pretend to water them.</blockquote>

**/
Discourse.Dialect.registerInline('"', function(str, match, prev) {

  // Make sure we're on a line boundary
  var last = prev[prev.length - 1];
  if (typeof last === "string") { return; }

  if (str.length > 2 && str.charAt(0) === '"' && str.charAt(str.length-1) === '"') {
    var inner = str.substr(1, str.length-2);
    if (inner.indexOf('"') === -1 && inner.indexOf("\n") === -1) {
      return [str.length, ['blockquote', inner]];
    }
  }
});
