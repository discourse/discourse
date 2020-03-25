import highlightText, { CLASS_NAME } from "discourse/lib/highlight-text";
import { fixture } from "helpers/qunit-helpers";

QUnit.module("lib:highlight-text");

QUnit.test("highlighting text", assert => {
  fixture().html(
    `
    <p>This is some text to highlight</p>
    `
  );

  highlightText(fixture(), "some text");

  const terms = [];

  fixture(`.${CLASS_NAME}`).each((_, elem) => {
    terms.push(elem.textContent);
  });

  assert.equal(
    terms.join(" "),
    "some text",
    "it should highlight the terms correctly"
  );
});
