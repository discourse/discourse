import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DPill from "discourse/ui-kit/d-pill";

module("Integration | ui-kit | DPill", function (hooks) {
  setupRenderingTest(hooks);

  test("shows its label", async function (assert) {
    await render(<template><DPill @label="Tomorrow" /></template>);

    assert.dom(".d-pill").hasText("Tomorrow", "the label is the pill's text");
  });

  test("is neutral when no type is given", async function (assert) {
    await render(<template><DPill @label="Tomorrow" /></template>);

    assert
      .dom(".d-pill")
      .hasAttribute("class", "d-pill", "no type modifier is added");
  });

  for (const type of ["neutral", "info", "success", "warning", "danger"]) {
    test(`marks the ${type} type`, async function (assert) {
      await render(
        <template><DPill @label="Status" @type={{type}} /></template>
      );

      assert
        .dom(".d-pill")
        .hasAttribute("class", `d-pill --${type}`, "only that type's modifier");
    });
  }

  test("shows an icon before the label only when given one", async function (assert) {
    await render(
      <template>
        <DPill @label="Paused" />
        <DPill @icon="circle" @label="Live now" @type="success" />
      </template>
    );

    assert
      .dom(".d-pill:first-child .d-icon")
      .doesNotExist("no icon by default");
    assert
      .dom(".d-pill:last-child .d-icon-circle")
      .hasAttribute("aria-hidden", "true", "the icon is decorative");
    assert.strictEqual(
      find(".d-pill:last-child").firstChild.nodeName,
      "svg",
      "the icon comes before the label"
    );
    assert
      .dom(".d-pill:last-child")
      .hasText("Live now", "the icon adds no text");
  });

  test("passes attributes to the pill", async function (assert) {
    await render(
      <template>
        <DPill class="topic-day" title="Wednesday" @label="Tomorrow" />
      </template>
    );

    assert
      .dom(".d-pill")
      .hasClass("topic-day", "a class joins the pill's own")
      .hasAttribute("title", "Wednesday", "other attributes reach it");
  });
});
