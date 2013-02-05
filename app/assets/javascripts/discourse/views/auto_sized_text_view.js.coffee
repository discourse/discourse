Discourse.AutoSizedTextView = Ember.View.extend
  render: (buffer)->
    null
 
  didInsertElement: (e) ->
    me = @$()
    me.text(@get('content'))
    lh = lineHeight = parseInt(me.css("line-height"))
    fontSize =  parseInt(me.css("font-size"))

    while me.height() > lineHeight && fontSize > 12
      fontSize -= 1
      lh -=1
      me.css("font-size", "#{fontSize}px")
      me.css("line-height", "#{lh}px")
    


