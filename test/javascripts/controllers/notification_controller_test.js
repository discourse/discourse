var controller;
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
var postUrlStub = "post-url-stub";

module("Discourse.NotificationController", {
  setup: function() {
    sinon.stub(Discourse.Utilities, "postUrl").returns(postUrlStub);

    controller = Discourse.NotificationController.create({
      content: notificationFixture
    });
  },

  teardown: function() {
    Discourse.Utilities.postUrl.restore();
  }
});

test("scope property is correct", function() {
  equal(controller.get("scope"), "notifications.mentioned");
});

test("username property is correct", function() {
  equal(controller.get("username"), "velesin");
});

test("link property returns empty string when there is no topic title", function() {
  var fixtureWithEmptyTopicTitle = _.extend({}, notificationFixture, {data: {topic_title: ""}});
  Ember.run(function() {
    controller.set("content", fixtureWithEmptyTopicTitle);
  });

  equal(controller.get("link"), "");
});

test("link property returns correctly built link when there is a topic title", function() {
  var $link = $(controller.get("link"));

  ok(Discourse.Utilities.postUrl.calledWithExactly("a-slug", 1234, 1), "URL is generated with the correct slug, topic ID and post number");
  equal($link.attr("href"), postUrlStub, "generated link points to a correct URL");
  equal($link.text(), "some title", "generated link has correct text");
});
