(function() {

  Discourse.TopicStatusView.prototype.on("addCustomIcon", function(buffer) {

    // Add icon for closed tasks
    var topic = this.get('topic');
    if (topic.get('archetype') === 'task') {
      var icon = 'cog';
      if (topic.get('complete')) icon = 'ok';
      this.renderIcon(buffer, icon, 'task');
    }
        
  });

  Discourse.TopicStatusView.reopen({
    taskComplete: function() {
      this.rerender();
    }.observes('topic.complete')
  })

}).call(this); 