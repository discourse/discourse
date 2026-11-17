import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";

const TIME = new Date(2020, 0, 5, 15, 4).getTime();

module("Integration | ui-kit | Helper | dAgeWithTooltip", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a tiny relative age with the long date as its title", async function (assert) {
    await render(<template>{{dAgeWithTooltip TIME}}</template>);

    assert
      .dom(".relative-date")
      .hasAttribute("data-time", String(TIME))
      .hasAttribute("data-format", "tiny")
      .hasAttribute("title", "Jan 5, 2020 3:04 pm");
  });

  test("passes the options on, and can drop the title", async function (assert) {
    await render(
      <template>{{dAgeWithTooltip TIME format="medium" title=false}}</template>
    );

    assert
      .dom(".relative-date")
      .hasAttribute("data-format", "medium")
      .doesNotHaveAttribute("title");
  });
});
