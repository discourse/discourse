import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import stripWhitespace, {
  _checkStripWhitespace,
} from "discourse/helpers/strip-whitespace";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | strip-whitespace", function (hooks) {
  setupRenderingTest(hooks);

  test("it works", async function (assert) {
    await render(
      <template>
        <div class="stripped">
          {{#stripWhitespace}}
            <div class="">
              <p> Hello, World! </p>
            </div>
          {{/stripWhitespace}}
        </div>

        <div class="not-stripped">
          <div class="">
            <p> Hello, World! </p>
          </div>
        </div>
      </template>
    );
    assert.strictEqual(
      this.element.querySelector(".stripped div").outerHTML,
      `<div class=""><p>Hello, World!</p></div>`
    );
    assert.true(
      /<div class="">\s+<p> Hello, World! <\/p>\s+<\/div>/.test(
        this.element.querySelector(".not-stripped div").outerHTML
      ),
      "whitespace is not stripped in the non-stripped block"
    );
  });

  test("throws an error if called incorrectly", async function (assert) {
    // Unfortunately we can't actually test rendering errors in qunit tests...
    // So let's just test some internals of the error-throwing mechanism.

    assert.throws(
      () => {
        stripWhitespace();
      },
      /stripWhitespace should be imported without renaming/,
      "throws error when called directly"
    );

    assert.throws(
      () => {
        _checkStripWhitespace();
      },
      /stripWhitespace should be imported without renaming/,
      "_checkStripWhitespace works"
    );
  });
});
