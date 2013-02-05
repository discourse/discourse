(function() {

  Discourse.PrependPostView.prototype.on("prependPostContent", function(event) {

    // Append our template for the poll controls
    if (this.get('controller.content.archetype') == 'poll') {
      this.get('childViews').pushObject(Discourse.VoteControlsView.create());     
    }
    
  });

}).call(this); 