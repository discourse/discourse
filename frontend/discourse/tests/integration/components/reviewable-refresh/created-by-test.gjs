import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CreatedBy from "discourse/components/reviewable-refresh/created-by";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | reviewable-refresh | created-by",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders user avatar and name when user is provided", async function (assert) {
      const user = {
        id: 1,
        username: "testuser",
        avatar_template: "/images/avatar.png",
      };

      await render(<template><CreatedBy @user={{user}} /></template>);

      assert.dom(".created-by").exists("renders the created-by container");

      assert.dom(".created-by .avatar").exists("renders user avatar");

      assert
        .dom(".created-by .username")
        .containsText("testuser", "displays the username");
    });

    test("renders deleted user icon when no user is provided", async function (assert) {
      await render(<template><CreatedBy /></template>);

      assert.dom(".created-by").exists("renders the created-by container");

      assert
        .dom(".created-by .d-icon-trash-can")
        .exists("renders trash icon for deleted user");

      assert
        .dom(".created-by .deleted-user-avatar")
        .exists("has deleted-user-avatar class on icon");

      assert
        .dom(".created-by .avatar")
        .doesNotExist("does not render user avatar");
    });
  }
);
