import User from "discourse/models/user";

QUnit.module("model:topic-details");

import Topic from "discourse/models/topic";

var buildDetails = function(id) {
  var topic = Topic.create({ id: id });
  return topic.get("details");
};

QUnit.test("defaults", assert => {
  var details = buildDetails(1234);
  assert.present(details, "the details are present by default");
  assert.ok(!details.get("loaded"), "details are not loaded by default");
});

QUnit.test("updateFromJson", assert => {
  var details = buildDetails(1234);

  details.updateFromJson({
    allowed_users: [{ username: "eviltrout" }]
  });

  assert.equal(
    details.get("allowed_users.length"),
    1,
    "it loaded the allowed users"
  );
  assert.containsInstance(details.get("allowed_users"), User);
});
