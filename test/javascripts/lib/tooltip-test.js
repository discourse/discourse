import { registerTooltip, registerHoverTooltip } from "discourse/lib/tooltip";
import { fixture } from "helpers/qunit-helpers";

// prettier-ignore
QUnit.module("lib:tooltip", {
  beforeEach() {
    fixture().html(
      `
        <a class='test-text-link' data-tooltip='XSS<s onmouseover\=alert(document.domain)>XSS'>test</a>
        <a class='test-html-link' data-html-tooltip='<p>test</p>'>test</a>
      `
    );
  }
});

QUnit.test("text support", async assert => {
  const $testTextLink = fixture(".test-text-link");
  registerTooltip($testTextLink);

  await $testTextLink.click();

  assert.equal(
    fixture(".tooltip-content")
      .html()
      .trim(),
    "XSS&lt;s onmouseover=alert(document.domain)&gt;XSS",
    "it prevents XSS injection"
  );

  assert.equal(
    fixture(".tooltip-content")
      .text()
      .trim(),
    "XSS<s onmouseover=alert(document.domain)>XSS",
    "it returns content as plain text"
  );
});

QUnit.test("html support", async assert => {
  const $testHtmlLink = fixture(".test-html-link");
  registerHoverTooltip($testHtmlLink);

  await $testHtmlLink.click();

  assert.equal(
    fixture(".tooltip-content")
      .html()
      .trim(),
    "<p>test</p>",
    "it doesn’t escape HTML"
  );

  assert.equal(
    fixture(".tooltip-content")
      .text()
      .trim(),
    "test",
    "it returns content as plain text"
  );
});
