import highlightSyntax from "discourse/lib/highlight-syntax";
import { module, test } from "qunit";
import { fixture } from "discourse/tests/helpers/qunit-helpers";

let siteSettings = { autohighlight_all_code: true },
  session = {
    highlightJsPath: "/assets/highlightjs/highlight-test-bundle.min.js",
  };

module("Unit | Utility | highlight-syntax", function () {
  test("highlighting code", async function (assert) {
    fixture().innerHTML = `
      <pre>
        <code class="language-ruby">
          def code
            puts 1 + 2
          end
        </code>
      </pre>
    `;

    await highlightSyntax(fixture(), siteSettings, session);

    assert.strictEqual(
      document
        .querySelector("code.language-ruby.hljs .hljs-keyword")
        .innerText.trim(),
      "def"
    );
  });

  test("highlighting code with HTML intermingled", async function (assert) {
    fixture().innerHTML = `
      <pre>
        <code class="language-ruby">
          <ol>
          <li>def code</li>
          <li>  puts 1 + 2</li>
          <li>end</li>
          </ol>
        </code>
      </pre>
    `;

    await highlightSyntax(fixture(), siteSettings, session);

    assert.strictEqual(
      document
        .querySelector("code.language-ruby.hljs .hljs-keyword")
        .innerText.trim(),
      "def"
    );

    // Checks if HTML structure was preserved
    assert.strictEqual(
      document.querySelectorAll("code.language-ruby.hljs ol li").length,
      3
    );
  });
});
