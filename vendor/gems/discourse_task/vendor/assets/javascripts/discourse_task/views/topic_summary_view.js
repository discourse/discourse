(function() {

  Discourse.TopicSummaryView.prototype.on("appendSummaryInformation", function(childViews) {
    // Add the poll information
    if (this.get('topic.archetype') === 'task') {
      childViews.pushObject(Discourse.View.create({
        tagName: 'section',
        classNames: ['information'],
        templateName: 'discourse_task/templates/about_task'
      }));
    }
  });

}).call(this);
