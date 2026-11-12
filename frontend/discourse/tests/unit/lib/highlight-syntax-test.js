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

  test("auto language is detected and the placeholder class removed", async function (assert) {
    fixture().innerHTML = `<pre><code class="lang-auto">def code
  puts 1 + 2
end</code></pre>`;

    await highlightSyntax(fixture(), siteSettings, {});

    assert.dom("pre code", fixture()).hasClass("hljs");
    assert
      .dom("pre code.lang-auto", fixture())
      .doesNotExist("removes the invalid lang-auto class");
  });

  test("large auto blocks are still detected via a sampled prefix", async function (assert) {
    // Comfortably larger than the detection sample so the sampling path is used.
    const bigContent = "def code\n  puts 1 + 2\nend\n".repeat(150);
    fixture().innerHTML = `<pre><code class="lang-auto">${bigContent}</code></pre>`;

    await highlightSyntax(fixture(), siteSettings, {});

    assert.dom("pre code", fixture()).hasClass("hljs");
    assert.dom("pre code .hljs-keyword", fixture()).exists();
    assert
      .dom("pre code.lang-auto", fixture())
      .doesNotExist("still removes the invalid lang-auto class");
  });

  test("large auto blocks with no detectable language are left as plain text", async function (assert) {
    fixture().innerHTML = `<pre><code class="lang-auto">${"\n".repeat(
      3000
    )}</code></pre>`;

    await highlightSyntax(fixture(), siteSettings, {});

    assert
      .dom("pre code", fixture())
      .doesNotHaveClass("hljs", "nothing detected, so it is not highlighted");
    assert
      .dom("pre code.lang-auto", fixture())
      .doesNotExist("still removes the invalid lang-auto class");
  });
});
