(function() {

  Discourse.TopicFooterButtonsView.prototype.on("additionalButtons", function(childViews) {
    var topic = this.get('topic');
    if (topic.get('archetype') == 'task' && topic.get('can_complete_task')) {

      // If we can complete the task:
      childViews.addObject(Discourse.ButtonView.createWithMixins({

        completeBinding: 'controller.content.complete',

        completeChanged: function () {
          this.rerender();
        }.observes('complete'),

        renderIcon: function (buffer) {
          if (!this.get('complete')) {
            buffer.push("<i class='icon-cog'></i>")
          }
        },

        text: function () {
          if (this.get('complete')) {
            return I18n.t("task.reverse");
          } else {
            return I18n.t("task.complete_action");
          }
        }.property('complete'),

        click: function(e) {
          this.get('controller').completeTask();
        }
      }));

    }
  });

}).call(this);


