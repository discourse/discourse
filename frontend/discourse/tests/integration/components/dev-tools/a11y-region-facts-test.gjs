import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import * as instrumentation from "discourse/static/dev-tools/a11y/instrumentation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const LIVE_REGION_SELECTOR =
  "[aria-live], [role='alert'], [role='log'], [role='status']";

module(
  "Integration | Component | dev-tools | a11y-region-facts",
  function (hooks) {
    setupRenderingTest(hooks);

    let fixtures;

    hooks.beforeEach(function () {
      fixtures = [];
    });

    hooks.afterEach(function () {
      fixtures.forEach((fixture) => fixture.remove());
      instrumentation.resetA11yInstrumentation();
    });

    function addRegion(id, attributes = `aria-live="polite"`) {
      const host = document.createElement("div");
      host.innerHTML = `<div id="${id}" ${attributes}></div>`;
      document.body.appendChild(host);
      fixtures.push(host);

      return host.firstElementChild;
    }

    function regionDetail(key) {
      return instrumentation
        .watchedLiveRegionDetails()
        .find((region) => region.key === key);
    }

    async function deliver(region, text) {
      region.textContent = text;
      await settled();
      await Promise.resolve();
    }

    function replacementFor(region) {
      const replacement = document.createElement("div");
      replacement.id = region.id;
      replacement.setAttribute("aria-live", "polite");
      region.replaceWith(replacement);
      instrumentation.attachLiveRegions();

      return replacement;
    }

    test("delivery history survives two replacements of the same keyed region", async function (assert) {
      let region = addRegion("replacement-region");
      instrumentation.attachLiveRegions();
      await deliver(region, "first delivery");

      region = replacementFor(region);
      region = replacementFor(region);

      const afterReplacements = regionDetail("id:replacement-region");
      assert.strictEqual(
        afterReplacements.deliveries,
        1,
        "both replacements inherit the delivery count"
      );
      assert.strictEqual(
        afterReplacements.lastText,
        "first delivery",
        "both replacements inherit the last delivered text"
      );
      assert.strictEqual(
        instrumentation
          .timelineEntries()
          .filter((entry) => entry.label === "live region replaced").length,
        2,
        "each replacement after a delivery is diagnosed"
      );

      await deliver(region, "after two replacements");

      assert.strictEqual(
        regionDetail("id:replacement-region").deliveries,
        2,
        "the replacement has one observer and adds one delivery"
      );
      assert.strictEqual(
        regionDetail("id:replacement-region").lastText,
        "after two replacements",
        "the replacement updates the inherited last text"
      );
    });

    test("repeated re-derivation replaces verdicts without accumulating findings or rows", function (assert) {
      const region = addRegion(
        "rederived-region",
        `role="alert" aria-live="assertive"`
      );
      instrumentation.attachLiveRegions();

      region.setAttribute("aria-live", "polite");
      for (let pass = 0; pass < 5; pass++) {
        instrumentation.attachLiveRegions();
      }

      assert.deepEqual(
        regionDetail("id:rederived-region").findings.map(({ id }) => id),
        ["live.politeness-contradicts-role"],
        "five passes retain one current contradiction"
      );
      assert.deepEqual(
        instrumentation.liveRegionFindings().map(({ id }) => id),
        ["live.politeness-contradicts-role"],
        "the aggregate contains no per-pass duplicates"
      );

      region.setAttribute("aria-live", "assertive");
      for (let pass = 0; pass < 5; pass++) {
        instrumentation.attachLiveRegions();
      }

      assert.deepEqual(
        regionDetail("id:rederived-region").findings.map(({ id }) => id),
        ["live.redundant-politeness"],
        "the repaired markup replaces rather than supplements the old verdict"
      );
      assert.strictEqual(
        instrumentation.timelineEntries().length,
        0,
        "mere region state never creates timeline rows"
      );
    });

    test("a region that loses and regains semantics resumes its own history", async function (assert) {
      const region = addRegion("returning-region");
      instrumentation.attachLiveRegions();
      await deliver(region, "before leaving");
      instrumentation.clearTimeline();

      region.removeAttribute("aria-live");
      instrumentation.attachLiveRegions();

      assert.strictEqual(
        regionDetail("id:returning-region"),
        undefined,
        "a semantically dead region is no longer watched"
      );
      assert.strictEqual(
        instrumentation
          .timelineEntries()
          .filter(
            (entry) =>
              entry.label === "live region left" &&
              entry.detail.includes("#returning-region")
          ).length,
        1,
        "the semantic departure is named exactly once"
      );

      region.setAttribute("aria-live", "polite");
      instrumentation.attachLiveRegions();

      assert.strictEqual(
        regionDetail("id:returning-region").deliveries,
        1,
        "the same element resumes its prior delivery count"
      );
      assert.strictEqual(
        regionDetail("id:returning-region").lastText,
        "before leaving",
        "the same element resumes its last delivered text"
      );
      assert.false(
        instrumentation
          .timelineEntries()
          .some((entry) => entry.label === "live region replaced"),
        "regaining semantics is not mistaken for element replacement"
      );

      await deliver(region, "after returning");

      assert.strictEqual(
        regionDetail("id:returning-region").deliveries,
        2,
        "the reattached observer contributes one further delivery"
      );
    });

    test("two regions on one channel keep independent delivery facts", async function (assert) {
      const first = addRegion("first-polite-region");
      const second = addRegion("second-polite-region");
      instrumentation.attachLiveRegions();

      first.textContent = "first message";
      second.textContent = "second message";
      await settled();
      await Promise.resolve();

      assert.deepEqual(
        [
          regionDetail("id:first-polite-region"),
          regionDetail("id:second-polite-region"),
        ].map(({ deliveries, lastText }) => ({ deliveries, lastText })),
        [
          { deliveries: 1, lastText: "first message" },
          { deliveries: 1, lastText: "second message" },
        ],
        "channel sharing does not merge region histories"
      );
      assert.strictEqual(
        instrumentation
          .timelineEntries()
          .filter((entry) => entry.kind === "delivered").length,
        2,
        "one write to each region yields two deliveries"
      );
    });

    test("changing a watched region id rekeys it without duplicating its observer", async function (assert) {
      const region = addRegion("old-region-id");
      instrumentation.attachLiveRegions();
      await deliver(region, "before rename");
      instrumentation.clearTimeline();

      region.id = "new-region-id";
      instrumentation.attachLiveRegions();
      await settled();

      assert.deepEqual(
        instrumentation
          .watchedLiveRegionDetails()
          .filter(({ description }) => description.includes("#new-region-id"))
          .map(({ key, deliveries, lastText }) => ({
            key,
            deliveries,
            lastText,
          })),
        [
          {
            key: "id:new-region-id",
            deliveries: 1,
            lastText: "before rename",
          },
        ],
        "the same element has one current key and keeps its history"
      );
      assert.strictEqual(
        instrumentation.timelineEntries().length,
        0,
        "changing identity metadata is state, not a departure and arrival"
      );

      await deliver(region, "after rename");

      assert.strictEqual(
        regionDetail("id:new-region-id").deliveries,
        2,
        "one post-rename write increments the count once"
      );
      assert.strictEqual(
        instrumentation
          .timelineEntries()
          .filter((entry) => entry.kind === "delivered").length,
        1,
        "one post-rename write emits one delivery row"
      );
    });

    test("watched region details contain no DOM nodes at any depth", function (assert) {
      addRegion("primitive-region", `role="alert" aria-live="polite"`);
      instrumentation.attachLiveRegions();

      function domNodePaths(value, path = "details", seen = new Set()) {
        if (value === null || typeof value !== "object") {
          return [];
        }
        if (value instanceof Node) {
          return [path];
        }
        if (seen.has(value)) {
          return [];
        }
        seen.add(value);

        if (value instanceof Map) {
          return [...value.entries()].flatMap(([key, nested]) => [
            ...domNodePaths(key, `${path}.<key>`, seen),
            ...domNodePaths(nested, `${path}.get(${String(key)})`, seen),
          ]);
        }
        if (value instanceof Set) {
          return [...value].flatMap((nested, index) =>
            domNodePaths(nested, `${path}.<set:${index}>`, seen)
          );
        }

        return Object.entries(value).flatMap(([key, nested]) =>
          domNodePaths(nested, `${path}.${key}`, seen)
        );
      }

      assert.deepEqual(
        domNodePaths(instrumentation.watchedLiveRegionDetails()),
        [],
        "the direct accessor is safe even though timeline leak checks do not walk it"
      );
    });

    test("one discovery pass performs one document-wide live-region scan", function (assert) {
      addRegion("single-scan-region");
      const querySelectorAll = sinon.spy(document, "querySelectorAll");

      try {
        instrumentation.attachLiveRegions();
      } finally {
        querySelectorAll.restore();
      }

      assert.strictEqual(
        querySelectorAll
          .getCalls()
          .filter(({ args: [selector] }) => selector === LIVE_REGION_SELECTOR)
          .length,
        1,
        "release and discovery share one enumeration of the document"
      );
    });
  }
);
