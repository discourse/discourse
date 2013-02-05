window.Discourse.Notification = Discourse.Model.extend Discourse.Presence,

  readClass: (->
    if @read then 'read' else ''
  ).property('read')

  url: (->
    return "" if @blank('data.topic_title')
    slug = @get('slug')
    "/t/#{slug}/#{@get('topic_id')}/#{@get('post_number')}"
  ).property()


  rendered: (->
    notificationName = Discourse.get('site.notificationLookup')[@notification_type]
    Em.String.i18n "notifications.#{notificationName}",
       username: @data.display_username
       link: "<a href='#{@get('url')}'>#{@data.topic_title}</a>"
  ).property()


window.Discourse.Notification.reopenClass
  
  create: (obj) ->
    result = @_super(obj)
    result.set('data', Em.Object.create(obj.data)) if obj.data
    result
