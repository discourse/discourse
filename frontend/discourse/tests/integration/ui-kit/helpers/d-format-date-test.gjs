import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";

const TIME = new Date(2020, 0, 5, 15, 4).getTime();

module("Integration | ui-kit | Helper | dFormatDate", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a medium relative age with a title", async function (assert) {
    await render(<template>{{dFormatDate TIME}}</template>);

    assert
      .dom(".relative-date.date")
      .hasAttribute("data-time", String(TIME))
      .hasAttribute("data-format", "medium")
      .hasAttribute("title", "Jan 5, 2020 3:04 pm");
  });

  test("keeps 'ago' when leaveAgo is 'true'", async function (assert) {
    await render(<template>{{dFormatDate TIME leaveAgo="true"}}</template>);

    assert.dom(".relative-date").hasAttribute("data-format", "medium-with-ago");
  });

  test("uses the given format", async function (assert) {
    await render(<template>{{dFormatDate TIME format="tiny"}}</template>);

    assert.dom(".relative-date").hasAttribute("data-format", "tiny");
  });

  test("drops the title with noTitle", async function (assert) {
    await render(<template>{{dFormatDate TIME noTitle=true}}</template>);

    assert.dom(".relative-date").doesNotHaveAttribute("title");
  });

  test("puts the prefix before the age", async function (assert) {
    await render(<template>{{dFormatDate TIME prefix="Gadget"}}</template>);

    assert.true(
      document.querySelector(".relative-date").textContent.startsWith("Gadget ")
    );
  });

  test("renders nothing without a date", async function (assert) {
    await render(
      <template>
        <div class="test">{{dFormatDate null}}</div>
      </template>
    );

    assert.dom(".test").hasNoText();
    assert.dom(".relative-date").doesNotExist();
  });
});
