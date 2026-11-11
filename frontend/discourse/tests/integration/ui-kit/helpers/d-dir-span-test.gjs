import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dDirSpan from "discourse/ui-kit/helpers/d-dir-span";

module("Integration | ui-kit | Helper | dDirSpan", function (hooks) {
  setupRenderingTest(hooks);

  test("wraps the escaped text in a span", async function (assert) {
    this.siteSettings.support_mixed_text_direction = false;

    await render(
      <template>
        <div class="test">{{dDirSpan "<b>bold</b>"}}</div>
      </template>
    );

    assert.dom(".test span").hasText("<b>bold</b>");
    assert.dom(".test span").doesNotHaveAttribute("dir");
    assert.dom(".test b").doesNotExist();
  });

  test("sets an automatic direction with mixed text direction", async function (assert) {
    this.siteSettings.support_mixed_text_direction = true;

    await render(
      <template>
        <div class="test">{{dDirSpan "text"}}</div>
      </template>
    );

    assert.dom(".test span").hasAttribute("dir", "auto");
  });

  test("keeps the HTML when htmlSafe is 'true'", async function (assert) {
    await render(
      <template>
        <div class="test">{{dDirSpan "<b>bold</b>" htmlSafe="true"}}</div>
      </template>
    );

    assert.dom(".test span b").hasText("bold");
  });

  test("escapes the text when htmlSafe is anything else", async function (assert) {
    await render(
      <template>
        <div class="test">{{dDirSpan "<b>bold</b>" htmlSafe="yes"}}</div>
      </template>
    );

    assert.dom(".test b").doesNotExist();
  });

  test("renders an empty span without text", async function (assert) {
    await render(
      <template>
        <div class="test">{{dDirSpan null}}</div>
      </template>
    );

    assert.dom(".test span").hasText("");
  });
});
