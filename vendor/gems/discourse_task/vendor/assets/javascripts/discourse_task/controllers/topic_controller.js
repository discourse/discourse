(function() {

  Discourse.TopicController.reopen({

    // Allow the user to complete the task
    completeTask: function(e) {
      this.get('content').toggleComplete();
      return false;
    }

  })

}).call(this);


