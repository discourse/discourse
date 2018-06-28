import { registerTooltip } from "discourse/lib/tooltip";

// prettier-ignore
QUnit.module("lib:tooltip", {
  beforeEach() {
    fixture().html(
      "<a class='test-link' data-tooltip='XSS<s onmouseover\=alert(document.domain)>XSS'>test</a>"
    );
  }
});

QUnit.test("it prevents XSS injection", assert => {
  const $testLink = fixture(".test-link");
  registerTooltip($testLink);
  $testLink.click();

  andThen(() => {
    assert.equal(
      fixture(".tooltip-content")
        .html()
        .trim(),
      "XSS&lt;s onmouseover=alert(document.domain)&gt;XSS"
    );
  });
});
