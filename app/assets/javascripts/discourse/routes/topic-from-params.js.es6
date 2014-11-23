// This route is used for retrieving a topic based on params

export default Discourse.Route.extend({

  setupController: function(controller, params) {
    params = params || {};
    params.track_visit = true;
    var topic = this.modelFor('topic'),
        postStream = topic.get('postStream');

    var topicController = this.controllerFor('topic'),
        topicProgressController = this.controllerFor('topic-progress'),
        composerController = this.controllerFor('composer');

    // I sincerely hope no topic gets this many posts
    if (params.nearPost === "last") { params.nearPost = 999999999; }

    postStream.refresh(params).then(function () {

      // TODO we are seeing errors where closest post is null and this is exploding
      // we need better handling and logging for this condition.

      // The post we requested might not exist. Let's find the closest post
      var closestPost = postStream.closestPostForPostNumber(params.nearPost || 1),
          closest = closestPost.get('post_number'),
          progress = postStream.progressIndexOfPost(closestPost);

      topicController.setProperties({
        currentPost: closest,
        enteredAt: new Date().getTime().toString(),
        highlightOnInsert: closest
      });

      topicProgressController.setProperties({
        progressPosition: progress,
        expanded: false
      });
      Discourse.URL.jumpToPost(closest);

      if (topic.present('draft')) {
        composerController.open({
          draft: Discourse.Draft.getLocal(topic.get('draft_key'), topic.get('draft')),
          draftKey: topic.get('draft_key'),
          draftSequence: topic.get('draft_sequence'),
          topic: topic,
          ignoreIfChanged: true
        });
      }
    });
  }

});
