(function() {

  Discourse.Topic.reopen({

    // Allow the user to complete the task
    toggleComplete: function() {
      this.toggleProperty('complete');
      this.set('completed_at', moment().format("d Mon, yyyy"));

      jQuery.ajax(this.get('url') + "/complete", {
        type: 'PUT',
        data: {
          complete: this.get('complete') ? 'true' : 'false'
        }

      });
    }

  })

}).call(this);


