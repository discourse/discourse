(function() {
  window.Discourse.TopicFooterButtonsView.reopen({

    replyButtonTextPoll: function() {
      return Em.String.i18n("topic.reply.poll");
    }.property()

  });
}).call(this);
