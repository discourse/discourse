import { module, test } from "qunit";
import AiUsage from "discourse/plugins/discourse-ai/discourse/components/ai-usage";

module("Unit | Component | AiUsage", function () {
  test("does not split smaller user lists", function (assert) {
    assert.strictEqual(componentWithUsers(5).userSplitPoint, 5);
  });

  test("splits large user lists into two columns", function (assert) {
    assert.strictEqual(componentWithUsers(25).userSplitPoint, 13);
  });
});

function componentWithUsers(count) {
  const component = Object.create(AiUsage.prototype);
  component.data = {
    users: Array.from({ length: count }, (_, index) => ({
      username: `user-${index}`,
    })),
  };
  return component;
}
