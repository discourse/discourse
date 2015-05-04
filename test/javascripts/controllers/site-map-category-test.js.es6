moduleFor("controller:site-map-category", 'controller:site-map-category', {
  needs: ['controller:site-map']
});

test("showTopicCount anonymous", function() {
  var controller = this.subject();
  ok(controller.get("showTopicCount"), 'true when anonymous');
});

test("showTopicCount logged in", function() {
  var controller = this.subject({ currentUser: Discourse.User.create() });
  ok(!controller.get("showTopicCount"), 'false when logged in');
});

test("unreadTotal default", function() {
  var controller = this.subject({ currentUser: Discourse.User.create() });
  ok(!controller.get('unreadTotal'), "empty by default");
});

test("unreadTotal with values", function() {
  var controller = this.subject({
    currentUser: Discourse.User.create(),
    model: { unreadTopics: 1, newTopics: 3 }
  });
  equal(controller.get('unreadTotal'), 4);
});
