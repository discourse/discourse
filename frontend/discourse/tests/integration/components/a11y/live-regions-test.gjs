import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { next, run } from "@ember/runloop";
import { service } from "@ember/service";
import { find, render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const REGIONS = [
  { type: "polite", selector: "#a11y-announcements-polite" },
  { type: "assertive", selector: "#a11y-announcements-assertive" },
];

module("Integration | Component | A11y | LiveRegions", function (hooks) {
  setupRenderingTest(hooks);

  let observers = [];

  hooks.afterEach(function () {
    observers.forEach((observer) => observer.disconnect());
    observers = [];
  });

  // A live region only speaks when its DOM text changes, so the mutation count is what a
  // screen reader reacts to. A text assertion alone cannot tell a delivered repeat from a
  // write that changed nothing, and the final text cannot tell whether something stale was
  // spoken on the way there.
  function watchTextMutations(selector) {
    const element = find(selector);
    const state = { count: 0, texts: [] };
    const observer = new MutationObserver(() => {
      state.count++;
      state.texts.push(element.textContent.trim());
    });

    observer.observe(element, {
      childList: true,
      characterData: true,
      subtree: true,
    });
    observers.push(observer);

    return state;
  }

  test("renders polite and assertive live regions", async function (assert) {
    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .exists("polite announcements element exists");
    assert
      .dom("#a11y-announcements-assertive")
      .exists("assertive announcements element exists");

    for (const [selector, live, role] of [
      ["#a11y-announcements-polite", "polite", "status"],
      ["#a11y-announcements-assertive", "assertive", "alert"],
    ]) {
      assert
        .dom(selector)
        .doesNotHaveAttribute("aria-live", "the wrapper is not a live region");
      assert
        .dom(`${selector} > *`)
        .exists({ count: 1 })
        .hasAttribute("role", role)
        .hasAttribute("aria-live", live)
        .hasAttribute("aria-atomic", "true");
    }
  });

  test("displays assertive messages", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    a11y.announce("Test assertive message", "assertive", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-assertive")
      .hasText("Test assertive message", "displays assertive message");
  });

  test("displays polite messages", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    a11y.announce("Test polite message", "polite", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .hasText("Test polite message", "displays polite message");
  });

  test("announce called during render does not trigger a backtracking assertion", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    // Mirrors DIconGridPickerContent: a getter read during render calls `announce`.
    // <A11yLiveRegions /> renders first and reads the tracked message map, so a
    // synchronous announce (write) later in the same render trips Ember's
    // backtracking-rerender assertion and breaks the render. The announcer is placed
    // AFTER the live regions to establish that read-before-write ordering.
    class RenderTimeAnnouncer extends Component {
      @service a11y;

      get announced() {
        this.a11y.announce("Announced during render", "polite", 500);
        return "";
      }

      <template>{{this.announced}}</template>
    }

    await render(
      <template>
        <A11yLiveRegions />
        <RenderTimeAnnouncer />
      </template>
    );

    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "Announced during render",
        "the render-time announcement is shown without a backtracking error"
      );
  });

  REGIONS.forEach(({ type, selector }) => {
    test(`re-announcing an identical ${type} message still reaches the live region`, async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);

      const mutations = watchTextMutations(selector);
      const a11y = getOwner(this).lookup("service:a11y");

      a11y.announce("1 result", type);
      await settled();
      const afterFirst = mutations.count;

      a11y.announce("1 result", type);
      await settled();

      assert.true(
        afterFirst > 0,
        "the first announcement reaches the region at all"
      );
      assert.true(
        mutations.count > afterFirst,
        "an identical repeat mutates the region again rather than being swallowed"
      );
      assert
        .dom(selector)
        .hasText("1 result", "and the region settles on the message");
    });
  });

  test("a repeat does not overwrite an announcement made while it was pending", async function (assert) {
    disableClearA11yAnnouncementsInTests();
    await render(<template><A11yLiveRegions /></template>);

    const a11y = getOwner(this).lookup("service:a11y");

    a11y.announce("1 result", "polite");
    await settled();

    // Delivering a repeat takes an extra tick, during which an unrelated caller can write
    // to the same region. The newest message has to be the one left standing.
    a11y.announce("1 result", "polite");
    a11y.announce("2 results", "polite");
    await settled();

    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "2 results",
        "the newest announcement survives the pending repeat"
      );
  });

  // VoiceOver remembers the last text each live element said and stays silent when the same text
  // comes back, even after the element was emptied in between. So every announcement goes into a
  // new element. That element has to be in the page before its text arrives, because text that
  // arrives with the element is not reliably read. An idle element holds nothing at all: an idle
  // character is read aloud ("space") whenever a message clears.
  //
  // "Nothing" is measured with the template's own newlines and indentation removed, but not a
  // non-breaking space, since that is the character a reader can hear.
  const spoken = (text) => text.replace(/[\t\n\r ]+/g, "");

  /**
   * Records each live element added to a region with the text it held when it arrived.
   */
  function watchNewElements(selector) {
    const region = find(selector);
    const added = [];
    const observer = new MutationObserver((records) => {
      for (const record of records) {
        for (const node of record.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE) {
            added.push({ element: node, text: spoken(node.textContent) });
          }
        }
      }
    });

    observer.observe(region, { childList: true });
    observers.push(observer);

    return added;
  }

  REGIONS.forEach(({ type, selector }) => {
    test(`an idle ${type} region holds nothing a reader could hear`, async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);

      assert.strictEqual(spoken(find(selector).textContent), "", "at rest");

      const a11y = getOwner(this).lookup("service:a11y");
      a11y.announce("no results", type);
      await settled();
      a11y.announce("", type);
      await settled();

      assert.strictEqual(
        spoken(find(selector).textContent),
        "",
        "and once a message clears"
      );
    });

    test(`every ${type} announcement lands in a new element that arrived empty`, async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);

      const added = watchNewElements(selector);
      const a11y = getOwner(this).lookup("service:a11y");
      const steps = [
        ["no results", "a first message"],
        ["no results", "an identical repeat"],
        ["1 result", "a different message"],
        ["", null],
        ["1 result", "a repeat after the region cleared"],
      ];

      for (const [message, label] of steps) {
        const before = added.length;
        a11y.announce(message, type);
        await settled();

        if (!label) {
          continue;
        }

        assert.strictEqual(
          added.length,
          before + 1,
          `${label} gets a new element`
        );
        const { element, text } = added.at(-1);
        assert.strictEqual(text, "", `${label}: the element arrives empty`);
        assert
          .dom(element)
          .hasText(message, `${label}: and then holds the message`);
        assert
          .dom(`${selector} > *`)
          .exists({ count: 1 }, `${label}: and replaces the previous element`);
      }
    });
  });

  test("a message superseded in the same turn never reaches the region", async function (assert) {
    disableClearA11yAnnouncementsInTests();
    await render(<template><A11yLiveRegions /></template>);

    const a11y = getOwner(this).lookup("service:a11y");
    a11y.announce("1 result", "polite");
    await settled();

    const mutations = watchTextMutations("#a11y-announcements-polite");

    a11y.announce("2 results", "polite");
    a11y.announce("3 results", "polite");
    await settled();

    assert.false(
      mutations.texts.includes("2 results"),
      "the superseded message is never written"
    );
    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "3 results",
        "the newest announcement is what the region ends on"
      );
  });

  // A run-loop timer fires late whenever the page is busy, and Backburner then runs every timer
  // that is due in one go, in deadline order. A message written a moment before the previous
  // message's clear falls due is followed straight away by that clear. The clock is moved instead
  // of waited on, which Backburner reads through `Date.now`.
  test("a clear that falls due together with a newer write leaves that write alone", async function (assert) {
    await render(<template><A11yLiveRegions /></template>);
    const a11y = getOwner(this).lookup("service:a11y");

    a11y.announce("1 result", "polite");
    await new Promise((resolve) => next(resolve));

    a11y.announce("2 results", "polite");
    sinon.stub(Date, "now").returns(Date.now() + 15);
    try {
      await waitUntil(() => a11y.liveRegionWriteCount("polite") === 2);
      assert.strictEqual(
        a11y.politeMessage,
        "2 results",
        "the earlier message's clear does not erase the newer one"
      );
    } finally {
      Date.now.restore();
    }
    await settled();
  });

  test("an announcement still pending at teardown is dropped", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    a11y.announce("1 result", "polite");
    run(() => a11y.destroy());
    await settled();

    assert.strictEqual(
      a11y.politeMessage,
      undefined,
      "teardown keeps the pending write from landing"
    );
  });
});
