import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import highlightSyntax from "discourse/lib/highlight-syntax";
import { fixture } from "discourse/tests/helpers/qunit-helpers";

const siteSettings = { autohighlight_all_code: true };

module("Unit | Utility | highlight-syntax", function (hooks) {
  setupTest(hooks);

  test("highlighting code", async function (assert) {
    fixture().innerHTML = `
      <pre>
        <code class="lang-ruby">
          def code
            puts 1 + 2
          end
        </code>
      </pre>
    `;

    await highlightSyntax(fixture(), siteSettings, {});

    assert.dom("code.lang-ruby.hljs .hljs-keyword", fixture()).hasText("def");
  });

  test("highlighting code with HTML intermingled", async function (assert) {
    fixture().innerHTML = `
      <pre>
        <code class="lang-ruby">
          <ol>
          <li>def code</li>
          <li>  puts 1 + 2</li>
          <li>end</li>
          </ol>
        </code>
      </pre>
    `;

    await highlightSyntax(fixture(), siteSettings, {});

    assert.dom("code.lang-ruby.hljs .hljs-keyword", fixture()).hasText("def");

    // Checks if HTML structure was preserved
    assert.dom("code.lang-ruby.hljs ol li", fixture()).exists({ count: 3 });
  });
});
