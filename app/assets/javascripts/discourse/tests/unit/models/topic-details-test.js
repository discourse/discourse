import { test, module } from "qunit";
import User from "discourse/models/user";

module("model:topic-details");

import Topic from "discourse/models/topic";

let buildDetails = function (id) {
  let topic = Topic.create({ id: id });
  return topic.get("details");
};

test("defaults", (assert) => {
  let details = buildDetails(1234);
  assert.present(details, "the details are present by default");
  assert.ok(!details.get("loaded"), "details are not loaded by default");
});

test("updateFromJson", (assert) => {
  let details = buildDetails(1234);

  details.updateFromJson({
    allowed_users: [{ username: "eviltrout" }],
  });

  assert.equal(
    details.get("allowed_users.length"),
    1,
    "it loaded the allowed users"
  );
  assert.containsInstance(details.get("allowed_users"), User);
});
