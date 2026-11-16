import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";

module(
  "Integration | ui-kit | Helper | dBoundAvatarTemplate",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a placeholder without a template", async function (assert) {
      await render(
        <template>
          <div class="test">{{dBoundAvatarTemplate "" "tiny"}}</div>
        </template>
      );

      assert.dom(".test .avatar-placeholder").exists();
      assert.dom(".test img").doesNotExist();
    });

    test("renders the avatar at the size, with the extra options", async function (assert) {
      const options = { title: "Gizmo" };

      await render(
        <template>
          <div class="test">
            {{dBoundAvatarTemplate "/gizmo/{size}.png" "tiny" options}}
          </div>
        </template>
      );

      assert
        .dom(".test img.avatar")
        .hasAttribute("width", "24")
        .hasAttribute("title", "Gizmo");
    });
  }
);
