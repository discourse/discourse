import highlightSearch, { CLASS_NAME } from "discourse/lib/highlight-search";
import { fixture } from "helpers/qunit-helpers";

QUnit.module("lib:highlight-search");

QUnit.test("highlighting text", assert => {
  fixture().html(
    `
    <p>This is some text to highlight</p>
    `
  );

  highlightSearch(fixture()[0], "some text");

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

QUnit.test("highlighting unicode text", assert => {
  fixture().html(
    `
    <p>This is some தமிழ் & русский text to highlight</p>
    `
  );

  highlightSearch(fixture()[0], "தமிழ் & русский");

  const terms = [];

  fixture(`.${CLASS_NAME}`).each((_, elem) => {
    terms.push(elem.textContent);
  });

  assert.equal(
    terms.join(" "),
    "தமிழ் & русский",
    "it should highlight the terms correctly"
  );
});
