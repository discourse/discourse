import { module, test } from "qunit";
import { collectContiguousOrphanRuns } from "discourse/lib/selection/preserve-list-structure";

module("Unit | Lib | selection | preserve-list-structure", function () {
  function createContainer(html) {
    const div = document.createElement("div");
    div.innerHTML = html;
    return div;
  }

  function getRuns(html) {
    return collectContiguousOrphanRuns(createContainer(html));
  }

  function runTexts(runs) {
    return runs.map((run) => run.map((li) => li.textContent.trim()));
  }

  module("collectContiguousOrphanRuns", function () {
    test("collects single run of consecutive LIs", function (assert) {
      const runs = getRuns("<li>A</li><li>B</li><li>C</li>");
      assert.strictEqual(runs.length, 1);
      assert.deepEqual(runTexts(runs), [["A", "B", "C"]]);
    });

    test("returns empty array when no LIs present", function (assert) {
      const runs = getRuns("<p>text</p><div>more</div>");
      assert.strictEqual(runs.length, 0);
    });

    test("whitespace text nodes do NOT break runs", function (assert) {
      const runs = getRuns("<li>A</li>   \n   <li>B</li>\t<li>C</li>");
      assert.strictEqual(runs.length, 1);
      assert.deepEqual(runTexts(runs), [["A", "B", "C"]]);
    });

    test("non-whitespace text breaks runs", function (assert) {
      const runs = getRuns("<li>A</li>separator<li>B</li>");
      assert.strictEqual(runs.length, 2);
      assert.deepEqual(runTexts(runs), [["A"], ["B"]]);
    });

    test("<br> elements break runs", function (assert) {
      const runs = getRuns("<li>A</li><br><li>B</li>");
      assert.strictEqual(runs.length, 2);
      assert.deepEqual(runTexts(runs), [["A"], ["B"]]);
    });

    test("<p> elements break runs", function (assert) {
      const runs = getRuns("<li>A</li><p>paragraph</p><li>B</li>");
      assert.strictEqual(runs.length, 2);
      assert.deepEqual(runTexts(runs), [["A"], ["B"]]);
    });

    test("multiple separators create multiple runs", function (assert) {
      const runs = getRuns(
        "<li>A</li><li>B</li><p>sep1</p><li>C</li><br><li>D</li><li>E</li>"
      );
      assert.strictEqual(runs.length, 3);
      assert.deepEqual(runTexts(runs), [["A", "B"], ["C"], ["D", "E"]]);
    });

    test("leading non-LI content is ignored", function (assert) {
      const runs = getRuns("<p>intro</p><li>A</li><li>B</li>");
      assert.strictEqual(runs.length, 1);
      assert.deepEqual(runTexts(runs), [["A", "B"]]);
    });

    test("trailing non-LI content ends the run", function (assert) {
      const runs = getRuns("<li>A</li><li>B</li><p>outro</p>");
      assert.strictEqual(runs.length, 1);
      assert.deepEqual(runTexts(runs), [["A", "B"]]);
    });

    test("HTML comments break runs", function (assert) {
      const container = createContainer("<li>A</li><li>B</li>");
      container.insertBefore(
        document.createComment("comment"),
        container.lastChild
      );
      const runs = collectContiguousOrphanRuns(container);
      assert.strictEqual(runs.length, 2);
      assert.deepEqual(runTexts(runs), [["A"], ["B"]]);
    });

    test("empty container returns empty array", function (assert) {
      const runs = getRuns("");
      assert.strictEqual(runs.length, 0);
    });

    test("single LI creates single run", function (assert) {
      const runs = getRuns("<li>Solo</li>");
      assert.strictEqual(runs.length, 1);
      assert.deepEqual(runTexts(runs), [["Solo"]]);
    });
  });
});
