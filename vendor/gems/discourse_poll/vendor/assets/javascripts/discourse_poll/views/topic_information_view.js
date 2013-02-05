(function() {

  Discourse.TopicSummaryView.prototype.on("appendSummaryInformation", function(childViews) {
    // Add the poll information
    if (this.get('topic.archetype') === 'poll') {
      childViews.pushObject(Em.View.create({
        tagName: 'section',
        classNames: ['information'],
        templateName: 'discourse_poll/templates/about_poll'
      }));
    }
  });

}).call(this); 