window.Discourse.UserStreamView = Ember.View.extend Discourse.Scrolling,
  templateName: 'user/stream'
  currentUserBinding: 'Discourse.currentUser'
  userBinding: 'controller.content'

  scrolled: (e) ->
    $userStreamBottom = $('#user-stream-bottom')
    return if $userStreamBottom.data('loading')
    return unless $userStreamBottom and (position = $userStreamBottom.position())
    docViewTop = $(window).scrollTop()
    windowHeight = $(window).height()
    docViewBottom = docViewTop + windowHeight

    @set('loading', true)
    if (position.top < docViewBottom)
      $userStreamBottom.data('loading', true)
      @set('loading', true)
      @get('controller.content').loadMoreUserActions =>
        @set('loading', false)
        Em.run.next =>
          $userStreamBottom.data('loading', null)
          

  willDestroyElement: ->
    Discourse.MessageBus.unsubscribe "/users/#{@get('user.username').toLowerCase()}"
    @unbindScrolling()

  didInsertElement: ->
    Discourse.MessageBus.subscribe "/users/#{@get('user.username').toLowerCase()}", (data)=>
      @get('user').loadUserAction(data)
    @bindScrolling()
