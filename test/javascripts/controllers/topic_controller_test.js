
var topic = Discourse.Topic.create({
  title: "Qunit Test Topic",
  participants: [
    {id: 1234,
     post_count: 4,
     username: "eviltrout"}
  ]
});


module("Discourse.TopicController", {
  setup: function() {
    this.topicController = controllerFor('topic', topic);
  }
});

test("editingMode", function() {
  var topicController = this.topicController;

  ok(!topicController.get('editingTopic'), "we are not editing by default");

  topicController.set('model.details.can_edit', false);
  topicController.editTopic();
  ok(!topicController.get('editingTopic'), "calling editTopic doesn't enable editing unless the user can edit");

  topicController.set('model.details.can_edit', true);
  topicController.editTopic();
  ok(topicController.get('editingTopic'), "calling editTopic enables editing if the user can edit");
  equal(topicController.get('newTitle'), topic.get('title'));
  equal(topicController.get('newCategoryId'), topic.get('category_id'));

  topicController.cancelEditingTopic();
  ok(!topicController.get('editingTopic'), "cancelling edit mode reverts the property value");
});