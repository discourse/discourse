import { module, test } from "qunit";
import {
  collectContiguousOrphanRuns,
  preserveListStructureInClonedContent,
} from "discourse/lib/selection/preserve-list-structure";

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

  // Creates a mock range whose commonAncestorContainer is the given element
  function mockRange(commonAncestor, startContainer, startOffset = 0) {
    return {
      commonAncestorContainer: commonAncestor,
      startContainer: startContainer || commonAncestor,
      startOffset,
      intersectsNode(node) {
        return commonAncestor.contains(node);
      },
    };
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

    test("nested lists inside LIs are preserved as single run", function (assert) {
      const runs = getRuns(
        "<li>A<ul><li>A1</li><li>A2</li></ul></li><li>B</li>"
      );
      assert.strictEqual(runs.length, 1);
      assert.strictEqual(runs[0].length, 2);
      assert.strictEqual(runs[0][0].textContent.trim(), "AA1A2");
    });
  });

  module("preserveListStructureInClonedContent", function () {
    test("wraps orphan LIs in a UL by default", function (assert) {
      const container = createContainer("<li>A</li><li>B</li>");
      const range = mockRange(container);

      preserveListStructureInClonedContent(container, range);

      assert.strictEqual(container.querySelectorAll(":scope > ul").length, 1);
      assert.strictEqual(container.querySelectorAll("li").length, 2);
    });

    test("wraps orphan LIs from an OL parent with correct start number", function (assert) {
      // Simulate original DOM with an OL starting at 3
      const original = createContainer(
        '<ol start="3"><li>C</li><li>D</li><li>E</li></ol>'
      );
      document.body.appendChild(original);

      const container = createContainer("<li>D</li><li>E</li>");
      const secondLi = original.querySelectorAll("li")[1];
      const range = mockRange(original, secondLi);

      preserveListStructureInClonedContent(container, range);

      assert.strictEqual(
        container.querySelector("ol")?.tagName,
        "OL",
        "orphan LIs are wrapped in OL"
      );
      const ol = container.querySelector("ol");
      assert.strictEqual(ol.getAttribute("start"), "4");
      assert.strictEqual(ol.querySelectorAll("li").length, 2);

      document.body.removeChild(original);
    });

    test("preserves already-wrapped list without modification", function (assert) {
      const original = createContainer(
        "<ul><li>A</li><li>B</li><li>C</li></ul>"
      );
      document.body.appendChild(original);

      const container = createContainer("<ul><li>B</li><li>C</li></ul>");
      const secondLi = original.querySelectorAll("li")[1];
      const range = mockRange(original, secondLi);

      preserveListStructureInClonedContent(container, range);

      assert.strictEqual(
        container.querySelectorAll(":scope > ul").length,
        1,
        "still one UL"
      );
      assert.strictEqual(container.querySelectorAll("li").length, 2);

      document.body.removeChild(original);
    });

    test("wraps content in LI when selection starts inside a list item", function (assert) {
      const original = createContainer("<ul><li>Hello world</li></ul>");
      document.body.appendChild(original);

      // Simulate selecting just the text node inside the LI
      const textNode = original.querySelector("li").firstChild;
      const container = createContainer("world");
      const range = mockRange(original, textNode, 6);

      preserveListStructureInClonedContent(container, range);

      assert.strictEqual(
        container.querySelector("ul")?.tagName,
        "UL",
        "content is wrapped in UL"
      );
      assert.strictEqual(
        container.querySelector("ul").querySelectorAll("li").length,
        1
      );

      document.body.removeChild(original);
    });

    test("handles selection spanning UL and OL with annotations", function (assert) {
      const container = createContainer(
        '<li data-original-list-tag="UL" data-original-start-number="1" data-original-is-tight="true">Bullet</li>' +
          '<li data-original-list-tag="OL" data-original-start-number="1" data-original-is-tight="true">Numbered</li>'
      );
      const range = mockRange(container);

      preserveListStructureInClonedContent(container, range);

      assert.strictEqual(
        container.querySelectorAll(":scope > ul").length,
        1,
        "UL item wrapped in UL"
      );
      assert.strictEqual(
        container.querySelectorAll(":scope > ol").length,
        1,
        "OL item wrapped in OL"
      );
    });

    test("no-op when container has no list content", function (assert) {
      const container = createContainer("<p>Just text</p>");
      const range = mockRange(container);

      preserveListStructureInClonedContent(container, range);

      assert.strictEqual(container.innerHTML, "<p>Just text</p>");
    });

    test("nested list items are not treated as orphans", function (assert) {
      const container = createContainer(
        "<ul><li>A<ul><li>A1</li><li>A2</li></ul></li><li>B</li></ul>"
      );
      const range = mockRange(container);

      preserveListStructureInClonedContent(container, range);

      assert.strictEqual(
        container.querySelectorAll(":scope > ul").length,
        1,
        "outer list is preserved"
      );
      assert.strictEqual(
        container.querySelectorAll("ul ul").length,
        1,
        "nested list is preserved"
      );
      assert.strictEqual(container.querySelectorAll("li").length, 4);
    });

    test("annotated OL items preserve start number continuity", function (assert) {
      const container = createContainer(
        '<li data-original-list-tag="OL" data-original-start-number="3" data-original-is-tight="true">Third</li>' +
          '<li data-original-list-tag="OL" data-original-start-number="4" data-original-is-tight="true">Fourth</li>'
      );
      const range = mockRange(container);

      preserveListStructureInClonedContent(container, range);

      assert.strictEqual(
        container.querySelector("ol")?.tagName,
        "OL",
        "items wrapped in OL"
      );
      assert.strictEqual(
        container.querySelector("ol").getAttribute("start"),
        "3",
        "OL starts at correct number"
      );
      assert.strictEqual(
        container.querySelector("ol").querySelectorAll("li").length,
        2
      );
    });

    test("non-contiguous OL annotations create separate lists", function (assert) {
      const container = createContainer(
        '<li data-original-list-tag="OL" data-original-start-number="1" data-original-is-tight="true">First</li>' +
          '<li data-original-list-tag="OL" data-original-start-number="5" data-original-is-tight="true">Fifth</li>'
      );
      const range = mockRange(container);

      preserveListStructureInClonedContent(container, range);

      const ols = container.querySelectorAll("ol");
      assert.strictEqual(
        ols.length,
        2,
        "non-contiguous numbers create separate OLs"
      );
      assert.strictEqual(ols[0].getAttribute("start"), null);
      assert.strictEqual(ols[1].getAttribute("start"), "5");
    });

    test("cleans up data attributes after wrapping", function (assert) {
      const container = createContainer(
        '<li data-original-list-tag="UL" data-original-start-number="1" data-original-is-tight="true">Item</li>'
      );
      const range = mockRange(container);

      preserveListStructureInClonedContent(container, range);

      const li = container.querySelector("li");
      assert.strictEqual(li.dataset.originalListTag, undefined);
      assert.strictEqual(li.dataset.originalStartNumber, undefined);
      assert.strictEqual(li.dataset.originalIsTight, undefined);
    });
  });
});
