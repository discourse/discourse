import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import IframedHtml from "discourse/components/iframed-html";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | iframed-html", function (hooks) {
  setupRenderingTest(hooks);

  test("appends the html into the iframe", async function (assert) {
    await render(
      <template>
        <IframedHtml
          @html="<h1 id='find-me'>hello</h1>"
          class="this-is-an-iframe"
        />
      </template>
    );

    assert
      .dom("iframe.this-is-an-iframe")
      .exists({ count: 1 }, "inserts an iframe");

    const iframe = document.querySelector(".iframed-html");
    assert.strictEqual(
      iframe.contentWindow.document.body.querySelectorAll("#find-me").length,
      1,
      "inserts the passed in html into the iframe"
    );
  });
});
