import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { next, run } from "@ember/runloop";
import { service } from "@ember/service";
import { find, render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DModal from "discourse/ui-kit/d-modal";
import I18n from "discourse-i18n";

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

  test("composes same-type announcements made in one flush instead of clobbering", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    // Two polite announcements in the same synchronous flush — e.g. an "item added"
    // message immediately followed by a re-filtered result count. The one-message-per-type
    // live region can only show one, so without composition the second deterministically
    // clobbers the first and "Added Foo" is never announced.
    a11y.announce("Added Foo", "polite", 500);
    a11y.announce("12 results", "polite", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "Added Foo. 12 results",
        "both same-flush messages are composed into one atomic announcement"
      );
  });

  test("dedupes identical same-type announcements made in one flush", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    // Two independent callers announcing the same phrase in one flush (e.g. two
    // subscribers both reporting the same result count). Repeating the identical
    // text in one atomic announcement is pure redundancy for a screen reader.
    a11y.announce("3 results", "polite", 500);
    a11y.announce("3 results", "polite", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "3 results",
        "the repeated message is announced once, not composed with itself"
      );
  });

  test("keeps polite and assertive announcements separate when made in one flush", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    a11y.announce("Polite one", "polite", 500);
    a11y.announce("Assertive one", "assertive", 500);
    a11y.announce("Polite two", "polite", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "Polite one. Polite two",
        "polite messages compose among themselves"
      );
    assert
      .dom("#a11y-announcements-assertive")
      .hasText(
        "Assertive one",
        "the assertive message is not folded in with the polite ones"
      );
  });

  test("joins composed announcements with the locale's sentence break", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const translations = I18n.translations[I18n.locale].js;
    const original = translations.a11y_announcement_separator;
    // Chinese and Japanese end a sentence with a full-width stop and no following space.
    translations.a11y_announcement_separator = "。";

    try {
      const a11y = getOwner(this).lookup("service:a11y");
      a11y.announce("Added Foo", "polite", 500);
      a11y.announce("12 results", "polite", 500);

      await render(<template><A11yLiveRegions /></template>);

      assert
        .dom("#a11y-announcements-polite")
        .hasText("Added Foo。12 results", "the translated separator is used");
    } finally {
      translations.a11y_announcement_separator = original;
    }
  });

  // A caller re-asserting what the region already says would otherwise be read out ahead of
  // the news it arrived with. Alone, a repeat is still delivered (see the repeat tests below).
  test("drops a restated message when the same flush carries something new", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    await render(<template><A11yLiveRegions /></template>);

    a11y.announce("3 results", "polite", 500);
    await settled();

    a11y.announce("3 results", "polite", 500);
    a11y.announce("Added Foo", "polite", 500);
    await settled();

    assert
      .dom("#a11y-announcements-polite")
      .hasText("Added Foo", "only the new message is announced");
  });

  test("an empty announcement discards the messages queued before it in the flush", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    await render(<template><A11yLiveRegions /></template>);

    a11y.announce("Stale", "polite", 500);
    a11y.announce("", "polite", 500);
    a11y.announce("Fresh", "polite", 500);
    await settled();

    assert
      .dom("#a11y-announcements-polite")
      .hasText("Fresh", "what came after the clear is announced on its own");
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

  // The record of what reached each live region, read by tooling that has to pair a delivery with
  // the calls it contains. Text alone cannot do that once same-tick calls are combined.
  module("announcementHistory", function () {
    function snapshot(record) {
      const { type, text, delivered, dropped } = record;
      return { type, text, delivered, dropped };
    }

    test("announce returns increasing call ids, and a call that throws gets none", async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");

      const first = a11y.announce("One", "polite");
      assert.throws(() => a11y.announce("Two", "nonsense"));
      const second = a11y.announce("Three", "polite");
      await settled();

      assert.strictEqual(typeof first, "number", "a call id is returned");
      assert.strictEqual(second, first + 1, "the call that threw used no id");
    });

    test("a lone message is recorded with its call", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);
      const a11y = getOwner(this).lookup("service:a11y");

      const id = a11y.announce("Saved", "polite");
      await settled();

      const [record] = a11y.announcementHistory;
      assert.strictEqual(typeof record.id, "number", "the record has an id");
      assert.deepEqual(snapshot(record), {
        type: "polite",
        text: "Saved",
        delivered: [id],
        dropped: [],
      });
    });

    test("same-tick messages are one record holding every call", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);
      const a11y = getOwner(this).lookup("service:a11y");

      const added = a11y.announce("Added Foo", "polite");
      const count = a11y.announce("12 results", "polite");
      await settled();

      assert.deepEqual(a11y.announcementHistory.map(snapshot), [
        {
          type: "polite",
          text: "Added Foo. 12 results",
          delivered: [added, count],
          dropped: [],
        },
      ]);
    });

    test("identical same-tick messages each count as delivered", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);
      const a11y = getOwner(this).lookup("service:a11y");

      const first = a11y.announce("3 results", "polite");
      const second = a11y.announce("3 results", "polite");
      await settled();

      assert.deepEqual(
        a11y.announcementHistory.map((record) => record.delivered),
        [[first, second]],
        "both calls are delivered by the one merged message"
      );
    });

    test("a restated message is recorded as dropped", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);
      const a11y = getOwner(this).lookup("service:a11y");

      a11y.announce("3 results", "polite");
      await settled();

      const restated = a11y.announce("3 results", "polite");
      const added = a11y.announce("Added Foo", "polite");
      await settled();

      assert.deepEqual(snapshot(a11y.announcementHistory.at(-1)), {
        type: "polite",
        text: "Added Foo",
        delivered: [added],
        dropped: [{ call: restated, reason: "restated" }],
      });
    });

    test("an empty announcement records the calls it discarded", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);
      const a11y = getOwner(this).lookup("service:a11y");

      const stale = a11y.announce("Stale", "polite");
      const clear = a11y.announce("", "polite");
      await settled();

      assert.deepEqual(a11y.announcementHistory.map(snapshot), [
        {
          type: "polite",
          text: "",
          delivered: [clear],
          dropped: [{ call: stale, reason: "cleared" }],
        },
      ]);
    });

    test("the history keeps only the newest 50 records", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);
      const a11y = getOwner(this).lookup("service:a11y");

      for (let index = 1; index <= 51; index++) {
        a11y.announce(`Message ${index}`, "polite");
        await settled();
      }

      const texts = a11y.announcementHistory.map((record) => record.text);
      assert.strictEqual(texts.length, 50, "capped at 50");
      assert.strictEqual(texts[0], "Message 2", "the oldest record is dropped");
      assert.strictEqual(texts.at(-1), "Message 51", "the newest is kept");
    });

    test("the records it returns cannot change the service", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);
      const a11y = getOwner(this).lookup("service:a11y");

      const id = a11y.announce("Saved", "polite");
      await settled();

      const [record] = a11y.announcementHistory;
      assert.true(Object.isFrozen(record), "the record is frozen");
      assert.true(Object.isFrozen(record.delivered), "its call list is frozen");
      assert.throws(() => record.delivered.push(99), "it cannot be changed");
      assert.deepEqual(
        a11y.announcementHistory[0].delivered,
        [id],
        "the service's own record is untouched"
      );
    });
  });

  module("inside a modal dialog", function () {
    // Browsers leave everything outside an open aria-modal dialog out of the accessibility
    // tree, so regions left at the root are never read while a modal is open.
    test("render inside the open modal and return when it closes", async function (assert) {
      disableClearA11yAnnouncementsInTests();
      const open = tracked(true);

      await render(
        <template>
          <A11yLiveRegions />
          {{#if open.value}}
            <DModal class="outer" @inline={{true}} @title="Outer">Body</DModal>
          {{/if}}
        </template>
      );

      assert
        .dom(".outer[aria-modal='true'] #a11y-announcements-polite")
        .exists("the polite region is inside the modal");
      assert
        .dom(".outer[aria-modal='true'] #a11y-announcements-assertive")
        .exists("the assertive region is inside the modal");

      getOwner(this).lookup("service:a11y").announce("Removed Staff");
      await settled();
      assert
        .dom(".outer #a11y-announcements-polite")
        .hasText("Removed Staff", "announcements reach the modal's region");

      open.value = false;
      await settled();

      assert
        .dom("#a11y-announcements-polite")
        .exists({ count: 1 }, "there is still exactly one polite region");
      assert.strictEqual(
        find("#a11y-announcements-polite").closest("[aria-modal]"),
        null,
        "the regions return to the page once the modal closes"
      );
    });

    test("move to a modal opened above another and back", async function (assert) {
      const outer = tracked(true);
      const inner = tracked(false);

      await render(
        <template>
          <A11yLiveRegions />
          {{#if outer.value}}
            <DModal class="outer" @inline={{true}} @title="Outer">Body</DModal>
          {{/if}}
          {{#if inner.value}}
            <DModal class="inner" @inline={{true}} @title="Inner">Body</DModal>
          {{/if}}
        </template>
      );

      inner.value = true;
      await settled();
      assert
        .dom(".inner #a11y-announcements-polite")
        .exists("the topmost modal holds the regions");

      inner.value = false;
      await settled();
      assert
        .dom(".outer #a11y-announcements-polite")
        .exists("closing it hands the regions back to the modal below");

      inner.value = true;
      await settled();
      outer.value = false;
      await settled();
      assert
        .dom(".inner #a11y-announcements-polite")
        .exists("closing a lower modal leaves them in the topmost one");
    });
  });
});
