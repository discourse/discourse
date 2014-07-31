var notificationFixture = {
  notification_type: 1, //mentioned
  post_number: 1,
  topic_id: 1234,
  slug: "a-slug",
  data: {
  topic_title: "some title",
    display_username: "velesin"
  }
};

moduleFor("controller:notification");

test("scope property is correct", function() {
  var controller = this.subject(notificationFixture);
  equal(controller.get("scope"), "notifications.mentioned");
});

test("username property is correct", function() {
  var controller = this.subject(notificationFixture);
  equal(controller.get("username"), "velesin");
});

test("link property returns empty string when there is no topic title", function() {
  var fixtureWithEmptyTopicTitle = _.extend({}, notificationFixture, {data: {topic_title: ""}});
  var controller = this.subject(fixtureWithEmptyTopicTitle);
  equal(controller.get("link"), "");
});

test("link property returns correctly built link when there is a topic title", function() {
  var controller = this.subject(notificationFixture);
  ok(controller.get("link").indexOf('/t/a-slug/1234') !== -1, 'has the correct URL');
  ok(controller.get("link").indexOf('some title') !== -1, 'has the correct title');
});
