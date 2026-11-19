import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DRelativeDate from "discourse/ui-kit/d-relative-date";

module("Integration | ui-kit | DRelativeDate", function (hooks) {
  setupRenderingTest(hooks);

  test("renders an auto-updating relative date with a tooltip", async function (assert) {
    const date = "2024-06-15T12:00:00Z";

    await render(<template><DRelativeDate @date={{date}} /></template>);

    assert
      .dom(".relative-date")
      .hasAttribute(
        "data-time",
        String(new Date(date).getTime()),
        "the date keeps updating"
      )
      .hasAttribute("title", /2024/, "the tooltip shows the full date");
  });
});
