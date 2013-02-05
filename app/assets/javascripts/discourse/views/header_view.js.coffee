window.Discourse.HeaderView = Ember.View.extend
  tagName: 'header'
  classNames: ['d-header', 'clearfix']
  classNameBindings: ['editingTopic']
  templateName: 'header'
  siteBinding: 'Discourse.site'
  currentUserBinding: 'Discourse.currentUser'
  categoriesBinding: 'site.categories'
  topicBinding: 'Discourse.router.topicController.content'
 
  showDropdown: ($target) ->
    elementId = $target.data('dropdown') || $target.data('notifications')
    $dropdown = $("##{elementId}")

    $li = $target.closest('li')
    $ul = $target.closest('ul')
    $li.addClass('active')
    $('li', $ul).not($li).removeClass('active')
    $('.d-dropdown').not($dropdown).fadeOut('fast')
    $dropdown.fadeIn('fast')
    $dropdown.find('input[type=text]').focus().select()

    $html = $('html')

    hideDropdown = () =>
      $dropdown.fadeOut('fast')
      $li.removeClass('active')
      $html.data('hide-dropdown', null)
      $html.off 'click.d-dropdown touchstart.d-dropdown'

    $html.on 'click.d-dropdown touchstart.d-dropdown', (e) =>
      return true if $(e.target).closest('.d-dropdown').length > 0
      hideDropdown()
    
    $html.data('hide-dropdown', hideDropdown)

    false

  showNotifications: ->
    $.get("/notifications").then (result) =>
      @set('notifications', result.map (n) => Discourse.Notification.create(n))

      # We've seen all the notifications now
      @set('currentUser.unread_notifications', 0)
      @set('currentUser.unread_private_messages', 0)

      @showDropdown($('#user-notifications'))

    false

  examineDockHeader: ->
    unless @docAt
      outlet = $('#main-outlet')
      return unless outlet && outlet.length == 1
      @docAt = outlet.offset().top

    offset = window.pageYOffset || $('html').scrollTop()

    if offset >= @docAt
      unless @dockedHeader
        $body = $('body')
        $body.addClass('docked')
        @dockedHeader = true
    else
      if @dockedHeader
        $('body').removeClass('docked')
        @dockedHeader = false
    

  willDestroyElement: ->
    $(window).unbind 'scroll.discourse-dock'
    $(document).unbind 'touchmove.discourse-dock'


  didInsertElement: ->
    @.$('a[data-dropdown]').on 'click touchstart', (e) => @showDropdown($(e.currentTarget))
    @.$('a.unread-private-messages, a.unread-notifications, a[data-notifications]').on 'click touchstart', (e) => @showNotifications(e)
    
    $(window).bind 'scroll.discourse-dock', => @examineDockHeader()
    $(document).bind 'touchmove.discourse-dock', => @examineDockHeader()
    @examineDockHeader()

    # Delegate ESC to the composer
    $('body').on 'keydown.header', (e) =>

      # Hide dropdowns
      if e.which == 27
        @.$('li').removeClass('active')
        @.$('.d-dropdown').fadeOut('fast') 

      if @get('editingTopic')
        @finishedEdit() if e.which == 13
        @cancelEdit() if e.which == 27
