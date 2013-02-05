window.Discourse.TopicSummaryView = Ember.ContainerView.extend Discourse.Presence,
  topicBinding: 'controller.content'
  classNameBindings: ['hidden', ':topic-summary']
  LINKS_SHOWN: 5

  collapsed: true
  allLinksShown: false

  showAllLinksControls: (->
    return false if @blank('topic.links')
    return false if @get('allLinksShown')
    return false if @get('topic.links.length') <= @LINKS_SHOWN
    true
  ).property('allLinksShown', 'topic.links')

  infoLinks: (->
    return [] if @blank('topic.links')
    allLinks = @get('topic.links')
    return allLinks if @get('allLinksShown')
    return allLinks.slice(0, @LINKS_SHOWN)
  ).property('topic.links', 'allLinksShown')

  newPostCreated: (->
    @rerender()
  ).observes('topic.posts_count')

  hidden: (->
    return true unless @get('post.post_number') == 1
    return false if @get('controller.content.archetype') == 'private_message'
    return true unless @get('controller.content.archetype') == 'regular'
    @get('controller.content.posts_count') < 2
  ).property()

  init: ->
    @_super()
    return if @get('hidden')

    @pushObject Em.View.create(templateName: 'topic_summary/info', topic: @get('topic'), summaryView: @)
    @trigger('appendSummaryInformation', @)

  toggleMore: ->
    @toggleProperty('collapsed')

  showAllLinks: ->
    @set('allLinksShown', true)

  appendSummaryInformation: (container) ->

    # If we have a best of view
    if @get('controller.showBestOf')
      container.pushObject Discourse.View.create
        templateName: 'topic_summary/best_of_toggle'
        tagName: 'section'
        classNames: ['information']

    # If we have a private message
    if @get('topic.isPrivateMessage')
      container.pushObject Discourse.View.create 
        templateName: 'topic_summary/private_message'
        tagName: 'section'
        classNames: ['information']


