(function() {

  Discourse.TopicStatusView.prototype.on("addCustomIcon", function(buffer) {

    // Add check icon for polls
    if (this.get('topic.archetype') === 'poll') {
      this.renderIcon(buffer, 'square-o', 'poll');
    }

  });

}).call(this);
