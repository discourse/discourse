import { render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableUser from "discourse/components/reviewable/user";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Reviewable | User", function (hooks) {
  setupRenderingTest(hooks);

  test("re-renders when the store updates the user fields and penalties", async function (assert) {
    this.site.user_fields = [{ id: 1, name: "Favorite color" }];
    const reviewable = this.owner
      .lookup("service:store")
      .createRecord("reviewable", {
        id: 901,
        user_fields: { 1: "blue" },
        target_user: { suspended_till: "2030-01-15T12:00:00Z" },
      });

    await render(
      <template><ReviewableUser @reviewable={{reviewable}} /></template>
    );

    reviewable.setProperties({
      user_fields: { 1: "green" },
      target_user: { suspended_till: "2031-01-15T12:00:00Z" },
    });
    await rerender();

    assert
      .dom(".user-field .value")
      .hasText("green", "shows the new user field value");
    assert
      .dom(".suspended-till .value")
      .includesText("2031", "shows the new suspension end");
  });
});
