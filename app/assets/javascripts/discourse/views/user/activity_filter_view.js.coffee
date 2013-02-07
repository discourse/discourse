window.Discourse.ActivityFilterView = Em.View.extend Discourse.Presence,
  tagName: 'li'
  classNameBindings: ['active']

  active: (->
    if content = @get('content')
      return parseInt(@get('controller.content.streamFilter')) is parseInt(Em.get(content, 'action_type'))
    else
      return @blank('controller.content.streamFilter')
  ).property('controller.content.streamFilter', 'content.action_type')

  render: (buffer) ->
    if content = @get('content')
      count = Em.get(content, 'count')
      description = Em.get(content, 'description')
    else
      count = @get('count')
      description = Em.String.i18n("user.filters.all")

    buffer.push("<a href='#'>#{description} <span class='count'>(#{count})</span><span class='icon-chevron-right'></span></a>")

  click: ->
    @get('controller.content').filterStream(@get('content.action_type'))
    false
