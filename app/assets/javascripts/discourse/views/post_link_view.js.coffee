window.Discourse.PostLinkView = Ember.View.extend
  tagName: 'li'
  classNameBindings: ['direction']

  direction: (->    
    return 'incoming' if @get('content.reflection')
    null
  ).property('content.reflection')

  render: (buffer) ->
    buffer.push("<a href='#{@get('content.url')}' class='track-link'>\n")
    buffer.push("<i class='icon icon-arrow-right'></i>")
    buffer.push(@get('content.title'))
    if clicks = @get('content.clicks')
      buffer.push("\n<span class='badge badge-notification clicks'>#{clicks}</span>")
    buffer.push("</a>")