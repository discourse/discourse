# Helper object for syntax highlighting. Uses highlight.js which is loaded 
# on demand.
window.Discourse.SyntaxHighlighting =

  apply: ($elem) ->
    $('pre code[class]', $elem).each (i, e) =>
      $LAB.script("/javascripts/highlight-handlebars.pack.js").wait ->
        hljs.highlightBlock(e)
