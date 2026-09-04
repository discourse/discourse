import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDragHandle from "discourse/ui-kit/d-drag-handle";

module("Integration | ui-kit | DDragHandle", function (hooks) {
  setupRenderingTest(hooks);

  test("is hidden from assistive technology and out of the tab order", async function (assert) {
    await render(<template><DDragHandle @label="Reorder Topics" /></template>);

    // The point of the component: a drag cannot be performed by keyboard, so
    // exposing the handle would offer a control that cannot be operated. The
    // keyboard path is a separate, operable control beside it.
    assert
      .dom(".d-drag-handle")
      .hasAttribute("aria-hidden", "true", "it is hidden from the a11y tree")
      .hasAttribute("tabindex", "-1", "and it is not a tab stop")
      .hasAttribute(
        "title",
        "Reorder Topics",
        "the label names what it drags for a sighted pointer user"
      );
  });

  test("passes attributes through so a consumer can register it with a source", async function (assert) {
    await render(
      <template>
        <DDragHandle
          @label="Reorder Topics"
          class="my-row__handle"
          data-link-name="Topics"
        />
      </template>
    );

    assert
      .dom(".d-drag-handle")
      .hasClass(
        "my-row__handle",
        "a consumer class lands alongside the component's own"
      )
      .hasAttribute(
        "data-link-name",
        "Topics",
        "and arbitrary attributes reach the element"
      );
  });
});
