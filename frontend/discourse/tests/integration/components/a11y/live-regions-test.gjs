import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { next, run } from "@ember/runloop";
import { service } from "@ember/service";
import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
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

    assert.dom("#a11y-announcements-polite").hasAttribute("role", "status");
    assert
      .dom("#a11y-announcements-polite")
      .hasAttribute("aria-live", "polite");
    assert
      .dom("#a11y-announcements-polite")
      .hasAttribute("aria-atomic", "true");

    assert.dom("#a11y-announcements-assertive").hasAttribute("role", "alert");
    assert
      .dom("#a11y-announcements-assertive")
      .hasAttribute("aria-live", "assertive");
    assert
      .dom("#a11y-announcements-assertive")
      .hasAttribute("aria-atomic", "true");
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

  // The reason the regions idle on a non-breaking space instead of on nothing. Blanking and
  // rewriting is enough for the DOM to record a change, but not for VoiceOver to speak one: it
  // compares what the region ends up saying with what it said before, and an empty middle state
  // leaves those identical. Idling on a character makes the middle state a real text — so a
  // reader who keeps typing a query that keeps matching nothing is told each time.
  //
  // The measure is "not whitespace-only", never "not empty". A region's text always carries the
  // template's own newlines and indentation, so an emptiness check passes whatever the component
  // renders — the first draft of this test did exactly that, and stayed green against a build
  // with no idle character at all. Ordinary whitespace collapses to nothing for a reader; a
  // non-breaking space is what survives, which is the whole reason it is the character chosen.
  REGIONS.forEach(({ type, selector }) => {
    test(`the ${type} region never falls silent, so an identical repeat is a change`, async function (assert) {
      disableClearA11yAnnouncementsInTests();
      await render(<template><A11yLiveRegions /></template>);

      const spoken = (text) => text.replace(/[\t\n\r ]+/g, "");
      const element = find(selector);
      assert.notStrictEqual(
        spoken(element.textContent),
        "",
        "a region with nothing to say still holds something a reader can notice leaving"
      );

      const a11y = getOwner(this).lookup("service:a11y");
      const seen = [];
      const observer = new MutationObserver(() =>
        seen.push(element.textContent)
      );
      observer.observe(element, {
        childList: true,
        characterData: true,
        subtree: true,
      });
      observers.push(observer);

      a11y.announce("no results", type);
      await settled();
      a11y.announce("no results", type);
      await settled();

      assert.true(
        seen.every((text) => spoken(text) !== ""),
        "and never falls silent on its way between two identical messages"
      );
      assert.true(
        seen.filter((text) => text.includes("no results")).length > 1,
        "so the second one is a text change rather than a rewrite of what was already there"
      );
    });
  });

  test("a repeat already in flight is never spoken once a newer announcement arrives", async function (assert) {
    disableClearA11yAnnouncementsInTests();
    await render(<template><A11yLiveRegions /></template>);

    const a11y = getOwner(this).lookup("service:a11y");

    a11y.announce("1 result", "polite");
    await settled();

    const mutations = watchTextMutations("#a11y-announcements-polite");

    // Advance one tick so the repeat has cleared the region but has not restored it yet.
    // A newer announcement arriving in that window has to win outright: asserting only the
    // final text would miss the region speaking the stale message on the way there.
    // Asserted as the absence of the message rather than as an empty region: a cleared region
    // idles on a non-breaking space rather than on nothing — see `A11yLiveRegions`.
    a11y.announce("1 result", "polite");
    await new Promise((resolve) => next(resolve));
    assert
      .dom("#a11y-announcements-polite")
      .doesNotIncludeText(
        "1 result",
        "the repeat clears the region before restoring it"
      );

    a11y.announce("2 results", "polite");
    await settled();

    assert.false(
      mutations.texts.includes("1 result"),
      "the superseded message is never put back into the region"
    );
    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "2 results",
        "the newest announcement is what the region ends on"
      );
  });

  test("a pending repeat does not write to a destroyed service", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");

    a11y.announce("1 result", "polite");
    await settled();

    // Advance a single tick so the repeat has blanked the region and scheduled its
    // restore, but the restore has not run yet.
    a11y.announce("1 result", "polite");
    await new Promise((resolve) => next(resolve));

    run(() => a11y.destroy());
    await settled();

    assert.strictEqual(
      a11y.politeMessage,
      undefined,
      "teardown cancels the pending restore instead of letting it write and re-arm a timer"
    );
  });
});
