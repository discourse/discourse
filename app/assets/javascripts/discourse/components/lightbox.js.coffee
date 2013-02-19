# Helper object for light boxes. Uses highlight.js which is loaded
# on demand.
window.Discourse.Lightbox =

  apply: ($elem) ->
    $('a.lightbox', $elem).each (i, e) =>
      $LAB.script("/javascripts/jquery.colorbox-min.js").wait ->
        $(e).colorbox()
