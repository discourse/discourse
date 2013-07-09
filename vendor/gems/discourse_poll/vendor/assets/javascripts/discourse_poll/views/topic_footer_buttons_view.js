(function() {
  window.Discourse.TopicFooterButtonsView.reopen({

    replyButtonTextPoll: function() {
      return I18n.t("topic.reply.poll");
    }.property()

  });
}).call(this);
