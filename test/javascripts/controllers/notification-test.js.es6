import Site from 'discourse/models/site';

const notificationFixture = {
  notification_type: 1, //mentioned
  post_number: 1,
  topic_id: 1234,
  slug: "a-slug",
  data: {
    topic_title: "some title",
    display_username: "velesin"
  },
  site: Site.current()
};

moduleFor("controller:notification");

test("scope property is correct", function() {
  const controller = this.subject(notificationFixture);
  equal(controller.get("scope"), "notifications.mentioned");
});

test("username property is correct", function() {
  const controller = this.subject(notificationFixture);
  equal(controller.get("username"), "velesin");
});

test("description property returns badge name when there is one", function() {
  const fixtureWithBadgeName = _.extend({}, notificationFixture, { data: { badge_name: "badge" } });
  const controller = this.subject(fixtureWithBadgeName);
  equal(controller.get("description"), "badge");
});

test("description property returns empty string when there is no topic title", function() {
  const fixtureWithEmptyTopicTitle = _.extend({}, notificationFixture, { data: { topic_title: "" } });
  const controller = this.subject(fixtureWithEmptyTopicTitle);
  equal(controller.get("description"), "");
});

test("description property returns topic title", function() {
  const fixtureWithTopicTitle = _.extend({}, notificationFixture, { data: { topic_title: "topic" } });
  const controller = this.subject(fixtureWithTopicTitle);
  equal(controller.get("description"), "topic");
});

test("url property returns badge's url when there is a badge", function() {
  const fixtureWithBadge = _.extend({}, notificationFixture, { data: { badge_id: 1, badge_name: "Badge Name"} });
  const controller = this.subject(fixtureWithBadge);
  equal(controller.get("url"), "/badges/1/badge-name");
});

test("url property returns topic's url when there is a topic", function() {
  const controller = this.subject(notificationFixture);
  equal(controller.get("url"), "/t/a-slug/1234");
});
