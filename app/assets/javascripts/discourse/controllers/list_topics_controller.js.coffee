Discourse.ListTopicsController = Ember.ObjectController.extend
  needs: ['list','composer']

  # If we're changing our channel
  previousChannel: null

  filterModeChanged: (->
    # Unsubscribe from a previous channel if necessary
    if previousChannel = @get('previousChannel')
      Discourse.MessageBus.unsubscribe "/#{previousChannel}"
      @set('previousChannel', null)

    filterMode = @get('controllers.list.filterMode')
    return unless filterMode

    channel = filterMode
    Discourse.MessageBus.subscribe "/#{channel}", (data) =>
      @get('content').insert(data)
    @set('previousChannel', channel)

  ).observes('controllers.list.filterMode')

  draftLoaded: (->
    draft = @get('content.draft')
    if(draft)
      @get('controllers.composer').open
        draft: draft
        draftKey: @get('content.draft_key'),
        draftSequence: @get('content.draft_sequence')
        ignoreIfChanged: true

  ).observes('content.draft')

  # Star a topic
  toggleStar: (topic) ->
    topic.toggleStar()
    false

  observer: (->
    @set('filterMode', @get('controllser.list.filterMode'))
  ).observes('controller.list.filterMode')


  # Show newly inserted topics
  showInserted: (e) ->

    # Move inserted into topics
    @get('content.topics').unshiftObjects @get('content.inserted')

    # Clear inserted
    @set('content.inserted', Em.A())

    false
