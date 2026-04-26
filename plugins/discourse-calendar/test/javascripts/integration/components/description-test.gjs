import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Description from "../../discourse/components/discourse-post-event/description";

module("Integration | Component | Description", function (hooks) {
  setupRenderingTest(hooks);

  test("renders plain text description", async function (assert) {
    await render(
      <template>
        <Description @descriptionHtml="Just some plain text" />
      </template>
    );

    assert.dom(".event-description__text").hasText("Just some plain text");
    assert.dom(".event-description__text a").doesNotExist();
  });

  test("renders linkified description HTML", async function (assert) {
    const html =
      'Check out <a href="https://example.com">https://example.com</a> for details';

    await render(
      <template><Description @descriptionHtml={{html}} /></template>
    );

    assert
      .dom(".event-description__text a")
      .hasAttribute("href", "https://example.com")
      .hasText("https://example.com");
  });
});
