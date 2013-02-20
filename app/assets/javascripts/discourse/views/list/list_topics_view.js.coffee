window.Discourse.ListTopicsView = Ember.View.extend Discourse.Scrolling, Discourse.Presence,
  templateName: 'list/topics'
  categoryBinding: 'Discourse.router.listController.category'
  filterModeBinding: 'Discourse.router.listController.filterMode'
  canCreateTopicBinding: 'controller.controllers.list.canCreateTopic'

  insertedCount: (->
    inserted = @get('controller.inserted')
    return 0 unless inserted
    inserted.length
  ).property('controller.inserted.@each')

  rollUp: (->
    @get('insertedCount') > Discourse.SiteSettings.new_topics_rollup
  ).property('insertedCount')

  loadedMore: false
  currentTopicId: null

  willDestroyElement: -> @unbindScrolling()

  allLoaded: (->
    !@get('loading') && !@get('controller.content.more_topics_url')
  ).property('loading', 'controller.content.more_topics_url')

  didInsertElement: ->
    @bindScrolling()
    eyeline = new Discourse.Eyeline('.topic-list-item')
    eyeline.on 'sawBottom', => @loadMore()

    if scrollPos = Discourse.get('transient.topicListScrollPos')
      Em.run.next -> $('html, body').scrollTop(scrollPos)
    else
      Em.run.next -> $('html, body').scrollTop(0)

    @set('eyeline', eyeline)
    @set('currentTopicId', null)

  loadMore: ->
    return if @get('loading')
    @set('loading', true)
    @get('controller.content').loadMoreTopics().then (hasMoreResults) =>
      @set('loadedMore', true)
      @set('loading', false)
      Em.run.next => @saveScrollPos()
      @get('eyeline').flushRest() unless hasMoreResults

  # Remember where we were scrolled to
  saveScrollPos: ->
    Discourse.set('transient.topicListScrollPos', $(window).scrollTop())

  # When the topic list is scrolled
  scrolled: (e) ->
    @saveScrollPos()
    @get('eyeline')?.update()

  footerMessage: (->
    return unless @get('allLoaded')

    content = @get('controller.content')
    split = content.get('filter').split('/')
    if content.get('topics.length') == 0
      Em.String.i18n("topics.none.#{split[0]}", category: split[1])
    else
      Em.String.i18n("topics.bottom.#{split[0]}", category: split[1])

  ).property('allLoaded', 'controller.content.topics.length')

