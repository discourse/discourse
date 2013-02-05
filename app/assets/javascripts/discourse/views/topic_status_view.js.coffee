window.Discourse.TopicStatusView = Discourse.View.extend
  classNames: ['topic-statuses']

  hasDisplayableStatus: (->
    return true if @get('topic.closed')
    return true if @get('topic.pinned')
    return true unless @get('topic.archetype.isDefault')
    return true unless @get('topic.visible')
    false
  ).property('topic.closed', 'topic.pinned', 'topic.visible')
 
  statusChanged: (->
    @rerender()
  ).observes('topic.closed', 'topic.pinned', 'topic.visible')

  renderIcon: (buffer, name, key) ->
    title = Em.String.i18n("topic_statuses.#{key}.help")
    buffer.push("<span title='#{title}' class='topic-status'><i class='icon icon-#{name}'></i></span>")
 
  render: (buffer) ->
    return unless @get('hasDisplayableStatus')

    # Allow a plugin to add a custom icon to a topic
    @trigger('addCustomIcon', buffer)
    
    @renderIcon(buffer, 'lock', 'locked') if @get('topic.closed')
    @renderIcon(buffer, 'pushpin', 'pinned') if @get('topic.pinned')
    @renderIcon(buffer, 'eye-close', 'invisible') unless @get('topic.visible')


