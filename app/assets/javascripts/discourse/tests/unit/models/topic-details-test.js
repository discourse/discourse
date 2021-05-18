import { module, test } from "qunit";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";

function buildDetails(id, topicParams = {}) {
  const topic = Topic.create(Object.assign({ id }, topicParams));
  return topic.get("details");
}

module("Unit | Model | topic-details", function () {
  test("defaults", function (assert) {
    let details = buildDetails(1234);
    assert.present(details, "the details are present by default");
    assert.ok(!details.get("loaded"), "details are not loaded by default");
  });

  test("updateFromJson", function (assert) {
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
});
