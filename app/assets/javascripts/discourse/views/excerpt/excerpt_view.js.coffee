window.Discourse.ExcerptView = Ember.ContainerView.extend
  classNames: ['excerpt-view']
  classNameBindings: ['position', 'size']

  childViews: ['closeView']

  closeView: Ember.View.create
    templateName: 'excerpt/close'

  # Position the tooltip on the screen. There's probably a nicer way of coding this.
  locationChanged: (->
    loc = @get('location')
    @.$().css(loc)
  ).observes('location')

  visibleChanged: (->
    return if @get('disabled')
    if @get('visible')
      unless @get('opening')
        @set('opening', true)
        @set('closing', false)
        $('.excerpt-view').stop().fadeIn('fast', => @set('opening', false))
    else
      unless @get('closing')
        @set('closing', true)
        @set('opening', false)
        $('.excerpt-view').stop().fadeOut('slow', => @set('closing', false))
  ).observes('visible')

  urlChanged: (->
    if @get('url')
      @set('visible', false)
      @ajax = $.ajax
        url: "/excerpt",
        data:
          url: @get('url')
        success: (tooltip) =>

          # Make sure we still have a URL (if it changed, we no longer care about this request.)
          return unless @get('url')
          $('.excerpt-view').stop().hide().css({opacity: 1})
          @set('closing', false)
          @set('location',@get('desiredLocation'))

          tooltip.created_at = Date.create(tooltip.created_at).relative() if tooltip.created_at

          viewClass = Discourse["Excerpt#{tooltip.type}View"] || Em.View

          excerpt = Em.Object.create(tooltip)
          excerpt.set('templateName', "excerpt/#{tooltip.type.toLowerCase()}")

          if @get('contentsView')
            @removeObject(@get('contentsView'))

          instance = viewClass.create(excerpt)
          instance.set("link", @hovering)
          @set('contentsView', instance)
          @addObject(instance)

          @set('excerpt', tooltip)
          @set('visible', true)
        error: =>
          @close()
        complete:
          @ajax = null

  ).observes('url')

  close: ->
    Em.run.cancel(@closeTimer)
    Em.run.cancel(@openTimer)
    @set('url', null)
    @set('visible', false)
    false

  closeSoon: ->
    @closeTimer = Em.run.later =>
      @close()
    , 200

  disable: ->
    @set('disabled',true)
    Em.run.cancel(@openTimer)
    Em.run.cancel(@closeTimer)
    @set('visible', false)
    @ajax.abort() if @ajax && @ajax.abort
    $('.excerpt-view').stop().hide()

  enable: ->
    @set('disabled', false)

  didInsertElement: ->

    # lets disable this puppy for now, it looks unprofessional 
    return

    # We don't do hovering on touch devices
    return if Discourse.get('touch')

    # If they dash into the excerpt, keep it open until they leave
    $('.excerpt-view').on 'mouseover', (e) => Em.run.cancel(@closeTimer)
    $('.excerpt-view').on 'mouseleave', (e) => @closeSoon()

    $('#main').on 'mouseover', '.excerptable', (e) =>

      $target = $(e.currentTarget)
      @hovering = $target

      # Make sure they're holding in place before we pop it up to mimimize annoyance
      Em.run.cancel(@openTimer)
      Em.run.cancel(@closeTimer)
      @openTimer = Em.run.later =>
        pos = $target.offset()
        pos.top = pos.top - $(window).scrollTop()

        positionText = $target.data('excerpt-position') || 'top'

        margin = 25
        height = @.$().height()
        topPosY = (pos.top - height) - margin
        bottomPosY = (pos.top + margin)

        
        # Switch to right if there's no room on top
        if positionText == 'top'
          positionText = 'bottom' if topPosY < 10

        switch positionText
          when 'right'
            pos.left = pos.left + $target.width() + margin
            pos.top = pos.top - $target.height()
          when 'left'
            pos.left = pos.left - @.$().width() - margin
            pos.top = pos.top - $target.height()
          when 'top'
            pos.top = topPosY
          when 'bottom'
            pos.top = bottomPosY

        if (pos.left || 0) <= 0 && (pos.top || 0) <= 0
          # somehow, sometimes, we are trying to position stuff in weird spots, just skip it
          return
        
        @set('position', positionText)
        @set('desiredLocation', pos)
        @set('size', $target.data('excerpt-size'))
        @set('url', $target.prop('href'))
      , if @get('visible') or @get('closing') then 100 else Discourse.SiteSettings.popup_delay

    $('#main').on 'mouseleave', '.excerptable', (e) =>
      Em.run.cancel(@openTimer)
      @closeSoon()
      

