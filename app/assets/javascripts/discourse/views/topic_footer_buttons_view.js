(function() {

  window.Discourse.TopicFooterButtonsView = Ember.ContainerView.extend({
    elementId: 'topic-footer-buttons',
    topicBinding: 'controller.content',
    init: function() {
      this._super();
      return this.createButtons();
    },
    /* Add the buttons below a topic
    */

    createButtons: function() {
      var topic;
      topic = this.get('topic');
      if (Discourse.get('currentUser')) {
        if (!topic.get('isPrivateMessage')) {
          /* We hide some controls from private messages
          */

          if (this.get('topic.can_invite_to')) {
            this.addObject(Discourse.ButtonView.create({
              textKey: 'topic.invite_reply.title',
              helpKey: 'topic.invite_reply.help',
              renderIcon: function(buffer) {
                return buffer.push("<i class='icon icon-group'></i>");
              },
              click: function() {
                return this.get('controller').showInviteModal();
              }
            }));
          }
          this.addObject(Discourse.ButtonView.createWithMixins({
            textKey: 'favorite.title',
            helpKey: 'favorite.help',
            favoriteChanged: (function() {
              return this.rerender();
            }).observes('controller.content.starred'),
            click: function() {
              return this.get('controller').toggleStar();
            },
            renderIcon: function(buffer) {
              var extraClass;
              if (this.get('controller.content.starred')) {
                extraClass = 'starred';
              }
              return buffer.push("<i class='icon-star " + extraClass + "'></i>");
            }
          }));
          this.addObject(Discourse.ButtonView.create({
            textKey: 'topic.share.title',
            helpKey: 'topic.share.help',
            renderIcon: function(buffer) {
              return buffer.push("<i class='icon icon-share'></i>");
            },
            'data-share-url': topic.get('url')
          }));
        }
        this.addObject(Discourse.ButtonView.createWithMixins({
          classNames: ['btn', 'btn-primary', 'create'],
          attributeBindings: ['disabled'],
          text: (function() {
            var archetype, customTitle;
            archetype = this.get('controller.content.archetype');
            if (customTitle = this.get("parentView.replyButtonText" + (archetype.capitalize()))) {
              return customTitle;
            }
            return Em.String.i18n("topic.reply.title");
          }).property(),
          renderIcon: function(buffer) {
            return buffer.push("<i class='icon icon-plus'></i>");
          },
          click: function() {
            return this.get('controller').reply();
          },
          helpKey: 'topic.reply.help',
          disabled: !this.get('controller.content.can_create_post')
        }));
        if (!topic.get('isPrivateMessage')) {
          this.addObject(Discourse.DropdownButtonView.createWithMixins({
            topic: topic,
            title: Em.String.i18n('topic.notifications.title'),
            longDescriptionBinding: 'topic.notificationReasonText',
            text: (function() {
              var icon, key;
              key = (function() {
                switch (this.get('topic.notification_level')) {
                  case Discourse.Topic.NotificationLevel.WATCHING:
                    return 'watching';
                  case Discourse.Topic.NotificationLevel.TRACKING:
                    return 'tracking';
                  case Discourse.Topic.NotificationLevel.REGULAR:
                    return 'regular';
                  case Discourse.Topic.NotificationLevel.MUTE:
                    return 'muted';
                }
              }).call(this);
              icon = (function() {
                switch (key) {
                  case 'watching':
                    return '<i class="icon-circle heatmap-high"></i>&nbsp;';
                  case 'tracking':
                    return '<i class="icon-circle heatmap-low"></i>&nbsp;';
                  case 'regular':
                    return '';
                  case 'muted':
                    return '<i class="icon-remove-sign"></i>&nbsp;';
                }
              })();
              return "" + icon + (Ember.String.i18n("topic.notifications." + key + ".title")) + "<span class='caret'></span>";
            }).property('topic.notification_level'),
            dropDownContent: [
              [Discourse.Topic.NotificationLevel.WATCHING, 'topic.notifications.watching'], 
              [Discourse.Topic.NotificationLevel.TRACKING, 'topic.notifications.tracking'], 
              [Discourse.Topic.NotificationLevel.REGULAR, 'topic.notifications.regular'], 
              [Discourse.Topic.NotificationLevel.MUTE, 'topic.notifications.muted']
            ],
            clicked: function(id) {
              return this.get('topic').updateNotifications(id);
            }
          }));
        }
        return this.trigger('additionalButtons', this);
      } else {
        // If not logged in give them a login control
        return this.addObject(Discourse.ButtonView.create({
          textKey: 'topic.login_reply',
          classNames: ['btn', 'btn-primary', 'create'],
          click: function() {
            var _ref;
            return (_ref = this.get('controller.controllers.modal')) ? _ref.show(Discourse.LoginView.create()) : void 0;
          }
        }));
      }
    }
  });

}).call(this);
