window.Discourse.TopicFooterButtonsView = Ember.ContainerView.extend
  elementId: 'topic-footer-buttons'
  topicBinding: 'controller.content'

  init: ->
    @_super()
    @createButtons()

  # Add the buttons below a topic
  createButtons: ->
    topic = @get('topic')

    if Discourse.get('currentUser')
      unless topic.get('isPrivateMessage')
        # We hide some controls from private messages

        if @get('topic.can_invite_to')
          @addObject Discourse.ButtonView.create
            textKey: 'topic.invite_reply.title'
            helpKey: 'topic.invite_reply.help'
            renderIcon: (buffer) -> buffer.push("<i class='icon icon-group'></i>")
            click: -> @get('controller').showInviteModal()

        @addObject Discourse.ButtonView.createWithMixins
          textKey: 'favorite.title'
          helpKey: 'favorite.help'
          favoriteChanged: (-> @rerender() ).observes('controller.content.starred')
          click: -> @get('controller').toggleStar()
          renderIcon: (buffer) ->
            extraClass = 'starred' if @get('controller.content.starred')
            buffer.push("<i class='icon-star #{extraClass}'></i>")

        @addObject Discourse.ButtonView.create
          textKey: 'topic.share.title'
          helpKey: 'topic.share.help'
          renderIcon: (buffer) -> buffer.push("<i class='icon icon-share'></i>")
          'data-share-url': topic.get('url')

      @addObject Discourse.ButtonView.createWithMixins
        classNames: ['btn', 'btn-primary', 'create']
        attributeBindings: ['disabled']
        text: (->
          archetype = @get('controller.content.archetype')
          return customTitle if customTitle = @get("parentView.replyButtonText#{archetype.capitalize()}")
          Em.String.i18n("topic.reply.title")
        ).property()
        renderIcon: (buffer) -> buffer.push("<i class='icon icon-plus'></i>")
        click: -> @get('controller').reply()
        helpKey: 'topic.reply.help'
        disabled: !@get('controller.content.can_create_post')

      unless topic.get('isPrivateMessage')
        @addObject Discourse.DropdownButtonView.createWithMixins
          topic: topic
          title: Em.String.i18n('topic.notifications.title')
          longDescriptionBinding: 'topic.notificationReasonText'
          text: (->
            key = switch @get('topic.notification_level')
              when Discourse.Topic.NotificationLevel.WATCHING then 'watching'
              when Discourse.Topic.NotificationLevel.TRACKING then 'tracking'
              when Discourse.Topic.NotificationLevel.REGULAR then 'regular'
              when Discourse.Topic.NotificationLevel.MUTE then 'muted'
            icon = switch key
              when 'watching' then '<i class="icon-circle heatmap-high"></i>&nbsp;'
              when 'tracking' then '<i class="icon-circle heatmap-low"></i>&nbsp;'
              when 'regular' then ''
              when 'muted' then '<i class="icon-remove-sign"></i>&nbsp;'
            "#{icon}#{Ember.String.i18n("topic.notifications.#{key}.title")}<span class='caret'></span>"
          ).property('topic.notification_level')
          dropDownContent: [
            [Discourse.Topic.NotificationLevel.WATCHING, 'topic.notifications.watching'],
            [Discourse.Topic.NotificationLevel.TRACKING, 'topic.notifications.tracking'],
            [Discourse.Topic.NotificationLevel.REGULAR, 'topic.notifications.regular'],
            [Discourse.Topic.NotificationLevel.MUTE, 'topic.notifications.muted']
          ]
          clicked: (id) ->
            @get('topic').updateNotifications(id)

      @trigger('additionalButtons', @)

    else
      # If not logged in give them a login control
      @addObject Discourse.ButtonView.create
        textKey: 'topic.login_reply'
        classNames: ['btn', 'btn-primary', 'create']
        click: -> @get('controller.controllers.modal')?.show(Discourse.LoginView.create())
