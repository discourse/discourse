import highlightSearch, { CLASS_NAME } from "discourse/lib/highlight-search";
import { module, test } from "qunit";
import { fixture } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Utility | highlight-search", function () {
  test("highlighting text", function (assert) {
    fixture().innerHTML = `
      <p>This is some text to highlight</p>
      `;

    highlightSearch(fixture(), "some text");

    const terms = [fixture(`.${CLASS_NAME}`).textContent];

    assert.strictEqual(
      terms.join(" "),
      "some text",
      "it should highlight the terms correctly"
    );
  });

  test("highlighting unicode text", function (assert) {
    fixture().innerHTML = `
      <p>This is some தமிழ் & русский text to highlight</p>
      `;

    highlightSearch(fixture(), "தமிழ் & русский");

    const terms = [fixture(`.${CLASS_NAME}`).textContent];

    assert.strictEqual(
      terms.join(" "),
      "தமிழ் & русский",
      "it should highlight the terms correctly"
    );
  });
});
