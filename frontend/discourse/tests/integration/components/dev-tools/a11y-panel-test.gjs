import { click, fillIn, focus, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import A11yButton from "discourse/static/dev-tools/a11y/button";
import { isAtBottom } from "discourse/static/dev-tools/a11y/follow";
import {
  attachCapture,
  attachLiveRegions,
  detachCapture,
  disconnectLiveRegions,
  installA11yTap,
  resetA11yInstrumentation,
  timelineEntries,
} from "discourse/static/dev-tools/a11y/instrumentation";
import A11yPanel from "discourse/static/dev-tools/a11y/panel";
import {
  clearDockPanels,
  closeDock,
  dockState,
} from "discourse/static/dev-tools/dock";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

async function settledAnnouncements() {
  await settled();
  await Promise.resolve();
}

/**
 * Oracle for the a11y panel UI (unit A3). It exercises the panel as dock-tab
 * content against the real instrumentation: entries come from real announce
 * calls, so the rows the panel shows are the rows a session would produce.
 */
module("Integration | Component | dev-tools | a11y-panel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.a11y = this.owner.lookup("service:a11y");
    disableClearA11yAnnouncementsInTests();
    installA11yTap();
  });

  hooks.afterEach(function () {
    resetA11yInstrumentation();
    closeDock();
    clearDockPanels();
    enableClearA11yAnnouncementsInTests();
  });

  test("the timeline lists entries oldest-first with their sequence numbers", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("first message", "polite");
    await settledAnnouncements();
    this.a11y.announce("second message", "polite");
    await settledAnnouncements();

    const rows = [...document.querySelectorAll(".dev-tools-a11y__entry")];
    assert.true(rows.length >= 2, "entries render as rows");

    const texts = rows.map((row) => row.textContent);
    assert.true(
      texts.findIndex((t) => t.includes("first message")) <
        texts.findIndex((t) => t.includes("second message")),
      "older entries come first"
    );
    assert
      .dom(rows[0].querySelector(".dev-tools-a11y__entry-seq"))
      .exists("rows carry their sequence");
  });

  // A region exists on the requested channel, but the announcement service
  // never writes into it. A repeat into a working region is NOT this case — the
  // region blanks in between, so the second write is really spoken.
  test("an intent with no delivery is flagged", async function (assert) {
    await render(
      <template>
        <div aria-live="polite"></div>
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("no results", "polite");
    await settledAnnouncements();

    assert
      .dom(".dev-tools-a11y__entry.--event .dev-tools-a11y__not-delivered")
      .exists("the later finding carries a not-delivered marker");
  });

  test("a repeat into a working region is not flagged", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("no results", "polite");
    await settledAnnouncements();
    this.a11y.announce("no results", "polite");
    await settledAnnouncements();

    assert
      .dom(".dev-tools-a11y__not-delivered")
      .doesNotExist("both deliveries were observed");
    assert
      .dom(".dev-tools-a11y__entry.--delivered")
      .exists({ count: 2 }, "the repeat is a second spoken entry");
  });

  test("the text filter narrows the timeline", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("alpha wolf", "polite");
    await settledAnnouncements();
    this.a11y.announce("beta fish", "polite");
    await settledAnnouncements();

    await fillIn(".dev-tools-a11y__toolbar input", "alpha");

    const visible = [...document.querySelectorAll(".dev-tools-a11y__entry")]
      .map((row) => row.textContent)
      .join(" ");
    assert.true(visible.includes("alpha wolf"));
    assert.false(visible.includes("beta fish"));
  });

  // "5 live regions" cannot tell a leak from bookkeeping, so the chip has to
  // name what is behind the number.
  test("the regions chip names the regions it is counting", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();
    await settled();

    assert
      .dom(".dev-tools-a11y__chip.--regions")
      .hasAttribute("title", /#a11y-announcements-polite \(polite\)/)
      .hasAttribute("title", /#a11y-announcements-assertive \(assertive\)/);
  });

  test("a cursor pointing outside the accessibility tree is flagged", async function (assert) {
    attachCapture();
    await render(
      <template>
        <A11yPanel />
        <input
          role="combobox"
          id="cb"
          aria-label="Category"
          aria-controls="lb"
          aria-activedescendant="row"
        />
        <ul role="listbox" id="lb" style="display: none">
          <li role="option" id="row">Bugs</li>
        </ul>
      </template>
    );

    await focus("#cb");

    // The combobox is visible; only its cursor target is not. The two must not
    // be conflated, or one defect is reported twice under two rules.
    //
    // Asserted by absence and presence rather than as the complete list: this
    // fixture is ordinary markup and will keep attracting new observations as
    // the catalogue grows, and none of those make the claim below less true.
    const recorded = timelineEntries().flatMap((entry) =>
      entry.findings.map(({ id }) => id)
    );

    assert.true(
      recorded.includes("cursor.target-hidden"),
      "the cursor target is out of the tree"
    );
    assert.false(
      recorded.includes("focus.not-in-tree"),
      "the visible focus does not inherit the cursor target's tree exclusion"
    );
    assert
      .dom(".dev-tools-a11y__timeline .dev-tools-a11y__problem")
      .exists({ count: 1 }, "one problem, and it is the one that matters");
    assert
      .dom(".dev-tools-a11y__timeline .dev-tools-a11y__problem")
      .hasText(i18n("dev_tools.a11y.findings.cursor.target_hidden"));

    detachCapture();
  });

  test("the problems toggle keeps only problem rows", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("healthy delivery", "polite");
    await settledAnnouncements();

    // Announced into a document with no watched region left, so this one has no
    // delivery to pair with and becomes the problem row the filter must keep.
    disconnectLiveRegions();
    this.a11y.announce("lost delivery", "polite");
    await settledAnnouncements();

    await click(".dev-tools-a11y__problems-toggle");

    assert.dom(".dev-tools-a11y__problems-toggle").hasAria("pressed", "true");
    const rows = [...document.querySelectorAll(".dev-tools-a11y__entry")];
    assert.true(rows.length >= 1, "problem rows remain");
    assert.true(
      rows.every((row) => row.className.includes("--")),
      "only flagged rows survive the filter"
    );
    assert.false(
      rows.some(
        (row) =>
          row.textContent.includes("healthy delivery") &&
          !row.querySelector(".dev-tools-a11y__not-delivered")
      ),
      "clean deliveries are filtered out"
    );
  });

  test("pause is a pressed toggle that stops new rows", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    await click(".dev-tools-a11y__pause");
    assert.dom(".dev-tools-a11y__pause").hasAria("pressed", "true");

    this.a11y.announce("while paused", "polite");
    await settledAnnouncements();
    assert.dom(".dev-tools-a11y__entry").doesNotExist();

    await click(".dev-tools-a11y__pause");
    this.a11y.announce("after resume", "polite");
    await settledAnnouncements();
    assert.dom(".dev-tools-a11y__entry").exists();
  });

  test("clear empties the timeline without a dialog", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("something", "polite");
    await settledAnnouncements();
    assert.dom(".dev-tools-a11y__entry").exists();

    await click(".dev-tools-a11y__clear");
    assert.dom(".dev-tools-a11y__entry").doesNotExist();
    assert
      .dom(".dialog-container")
      .doesNotExist("clearing is part of the repro loop, never confirmed");
  });

  test("the test-channel control proves the whole pipe", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    await click(".dev-tools-a11y__test-channel");
    await click(".dev-tools-a11y__test-polite");
    await settledAnnouncements();

    assert.dom(".dev-tools-a11y__entry.--intent").exists("intent recorded");
    assert
      .dom(".dev-tools-a11y__entry.--delivered")
      .exists("delivery recorded");
    assert
      .dom(".dev-tools-a11y__entry.--event")
      .doesNotExist("choosing from the menu never enters the trace");
  });

  test("the test channel can exercise the assertive path", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    await click(".dev-tools-a11y__test-channel");
    await click(".dev-tools-a11y__test-assertive");
    await settledAnnouncements();

    const rows = [...document.querySelectorAll(".dev-tools-a11y__entry")]
      .map((row) => row.textContent)
      .join(" ");
    // The channel is named rather than printed as `politeness=assertive`: the row
    // grammar puts it in the trigger gutter. The region is what proves the write
    // landed on the right channel, so it stays asserted.
    assert.true(
      rows.includes("assertive"),
      "the row names the assertive channel"
    );
    assert.true(
      rows.includes("a11y-announcements-assertive"),
      "delivery came from the assertive region"
    );
  });

  test("the regions chip warns loudly at zero", async function (assert) {
    await render(<template><A11yPanel /></template>);
    attachLiveRegions();
    await settled();

    assert
      .dom(".dev-tools-a11y__chip.--regions.--critical")
      .exists("zero regions is a critical chip");
    assert.dom(".dev-tools-a11y__warning").exists("and a banner");
    assert
      .dom(".dev-tools-a11y__warning[role='alert']")
      .doesNotExist("the banner must not be a live region the panel watches");
  });

  test("an empty timeline guides the user instead of showing nothing", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );

    assert.dom(".dev-tools-a11y__empty").exists();
  });

  /*
   * No click any more: unit 3a made the Inspector detail for the selection rather
   * than a view, so there is no pill to reach it through — it is simply there. The
   * claim this test was always making survives unchanged, which is that an Inspector
   * with nothing captured says so instead of rendering an empty shell.
   */
  test("the inspector says so when there is no snapshot", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );

    assert.dom(".dev-tools-a11y__inspector").exists("the inspector is present");
    assert
      .dom(".dev-tools-a11y__no-snapshot")
      .exists("without an interaction it says so");
  });

  test("panel controls never enter the trace", async function (assert) {
    await render(
      <template>
        <div class="dev-tools-toolbar">
          <A11yLiveRegions />
          <A11yPanel />
        </div>
      </template>
    );
    attachLiveRegions();

    await click(".dev-tools-a11y__pause");
    await click(".dev-tools-a11y__pause");

    assert
      .dom(".dev-tools-a11y__entry.--event")
      .doesNotExist("interacting with the panel records no events");
  });

  test("the toolbar button toggles the a11y dock tool", async function (assert) {
    await render(<template><A11yButton /></template>);

    await click(".toggle-a11y");
    assert.true(dockState().open);
    assert.strictEqual(dockState().activeTool, "a11y");
    assert.dom(".toggle-a11y").hasClass("--active");

    await click(".toggle-a11y");
    assert.false(dockState().open);
  });

  /*
   * Oracle for the scroller shell (unit 2c).
   *
   * Behaviour-preserving by design: nothing here should change what the panel
   * looks like. It exists because the scrolling element is currently the `<ol>`
   * itself, and that is the wrong element for three separate reasons that all bite
   * the units after it.
   *
   * An `<ol>` may only contain `<li>`, so a jump-to-latest control pinned to the
   * bottom of the scroller has nowhere valid to live. And the list is rendered
   * inside a conditional on there being entries, so the scrolling element is
   * DESTROYED whenever the timeline empties — which orphans any scroll or resize
   * observer attached to it, silently, exactly when follow mode would re-arm.
   */
  module("scroller shell (unit 2c)", function () {
    const SCROLLER = ".dev-tools-a11y__scroller";

    /*
     * The live regions are rendered alongside the panel deliberately. Inserting
     * the panel attaches region watching, and attaching it with NO regions in the
     * document records a `live region observer` meta row of its own — so a panel
     * rendered alone is never actually empty, and this test would be asserting
     * against the list rather than the empty state.
     */
    test("the scroller exists while the timeline is empty", async function (assert) {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );

      assert
        .dom(".dev-tools-a11y__entry")
        .doesNotExist("nothing has been recorded");
      assert
        .dom(SCROLLER)
        .exists("there is somewhere to scroll even while it is empty");
      assert
        .dom(`${SCROLLER} .dev-tools-a11y__empty`)
        .exists("and the empty state lives inside it");
    });

    /*
     * The property the later units depend on: one element that stays put. An
     * observer is attached once, and it must survive rows arriving and the trace
     * being cleared, because re-attaching on every change is the bug this shell
     * exists to make impossible.
     */
    test("the scroller is the same element across recording and clearing", async function (assert) {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );
      attachLiveRegions();

      // Asserted to exist before it is compared: two nulls are equal, so a
      // missing scroller would otherwise satisfy every identity check below.
      assert.dom(SCROLLER).exists("there is a scroller to hold on to");
      const empty = document.querySelector(SCROLLER);

      this.a11y.announce("something", "polite");
      await settledAnnouncements();
      assert
        .dom(".dev-tools-a11y__entry")
        .exists("rows arrived, so the list is no longer empty");
      assert.strictEqual(
        document.querySelector(SCROLLER),
        empty,
        "the same scroller, now with rows in it"
      );

      await click(".dev-tools-a11y__clear");

      assert.dom(".dev-tools-a11y__entry").doesNotExist("cleared");
      assert.strictEqual(
        document.querySelector(SCROLLER),
        empty,
        "and still the same scroller, so nothing was orphaned"
      );
    });

    /*
     * The scroller owns the `hidden` attribute, taken over from the list, which is
     * what decides whether the trace is on screen.
     *
     * This used to assert that showing the Inspector hid it. Unit 3a made the
     * Inspector DETAIL for the selection rather than a view of its own, so there is
     * nothing for the trace to give way to: the two are on screen together, which is
     * the whole point of the two-position Inspector. The remaining claim is that the
     * trace is not hidden by the Inspector existing — the attribute's real consumers
     * are the Regions and Sweep views, which arrive in 3c and 3d.
     */
    test("the trace and the Inspector are on screen together", async function (assert) {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );

      assert
        .dom(SCROLLER)
        .doesNotHaveAttribute("hidden", "the trace is showing");
      assert
        .dom(".dev-tools-a11y__inspector")
        .exists("and the Inspector is present alongside it, not instead of it");
    });

    // An `<ol>` may only contain `<li>`. Keeping that true is what leaves room for
    // the jump control to sit inside the scroller alongside the list.
    test("the list contains nothing but list items", async function (assert) {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );
      attachLiveRegions();

      this.a11y.announce("something", "polite");
      await settledAnnouncements();

      const stray = [
        ...document.querySelector(".dev-tools-a11y__timeline").children,
      ]
        .filter((child) => child.tagName !== "LI")
        .map((child) => child.tagName);

      assert.deepEqual(stray, [], "every child of the list is a list item");
      assert
        .dom(`${SCROLLER} .dev-tools-a11y__timeline`)
        .exists("and the list sits inside the scroller");
    });
  });

  /*
   * Oracle for follow mode and the jump control (unit 2d).
   *
   * The list appends to the bottom, so once it overflows every new event lands
   * below the fold — the failure mode for a live trace, since the newest row is
   * almost always the one being waited for.
   *
   * The box is sized by these tests rather than by the stylesheet. A rendering test
   * cannot rely on the panel's CSS being loaded, so the overflow it would otherwise
   * have to measure is not reliably there; setting the height here makes the
   * scrolling real and makes the test independent of `styles.css` entirely.
   */
  module("follow mode (unit 2d)", function () {
    const SCROLLER = ".dev-tools-a11y__scroller";
    const JUMP = ".dev-tools-a11y__jump";

    async function overflowingTrace(context, rows = 8) {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );
      attachLiveRegions();

      for (let index = 0; index < rows; index++) {
        context.a11y.announce(`message ${index}`, "polite");
        await settledAnnouncements();
      }

      const scroller = document.querySelector(SCROLLER);
      scroller.style.height = "40px";
      scroller.style.overflowY = "auto";
      await settled();

      return scroller;
    }

    async function scrollTo(scroller, top) {
      scroller.scrollTop = top;
      scroller.dispatchEvent(new Event("scroll"));
      await settled();
    }

    /*
     * The positive half of follow mode, and the one every other test here can do
     * without: an implementation that simply never scrolls satisfies "does not drag
     * a detached reader" and "offers a jump when detached" perfectly.
     */
    test("a row arriving while following brings it into view", async function (assert) {
      const scroller = await overflowingTrace(this);
      await scrollTo(scroller, scroller.scrollHeight);

      const before = scroller.scrollHeight;
      this.a11y.announce("the newest thing", "polite");
      await settledAnnouncements();

      assert.true(
        scroller.scrollHeight > before,
        "the list actually grew, so there was something to follow"
      );
      assert.true(
        isAtBottom({
          scrollTop: scroller.scrollTop,
          scrollHeight: scroller.scrollHeight,
          clientHeight: scroller.clientHeight,
        }),
        "and the newest row is still in view"
      );
    });

    /*
     * The count has to restart, not accumulate. Compared rather than pinned to an
     * exact number, because how many rows one announcement produces is the row
     * grammar's business and not what this test is about.
     */
    test("the unseen count restarts after re-engaging", async function (assert) {
      const scroller = await overflowingTrace(this);
      await scrollTo(scroller, scroller.scrollHeight);
      await scrollTo(scroller, 0);

      for (const message of ["one", "two"]) {
        this.a11y.announce(message, "polite");
        await settledAnnouncements();
      }
      const afterTwo = Number(
        document.querySelector(JUMP).textContent.match(/\d+/)?.[0]
      );
      assert.true(afterTwo >= 2, `two arrived unseen, got ${afterTwo}`);

      await click(JUMP);
      await scrollTo(scroller, 0);
      this.a11y.announce("three", "polite");
      await settledAnnouncements();

      const afterReset = Number(
        document.querySelector(JUMP).textContent.match(/\d+/)?.[0]
      );
      assert.true(
        afterReset < afterTwo,
        `the count restarted rather than continuing, got ${afterReset} after ${afterTwo}`
      );
    });

    /*
     * All three states in one test on purpose. Asserting only that the control is
     * ABSENT while pinned would pass on a panel that never renders it at all, so
     * each absence is paired with the presence that makes it mean something.
     */
    test("following releases on scroll-up and re-arms at the bottom", async function (assert) {
      const scroller = await overflowingTrace(this);

      assert.true(
        scroller.scrollHeight > scroller.clientHeight,
        "the fixture really overflows"
      );

      await scrollTo(scroller, scroller.scrollHeight);
      assert
        .dom(JUMP)
        .doesNotExist("nothing to jump to while already at the newest row");

      await scrollTo(scroller, 0);
      assert.dom(JUMP).exists("detached, so there is somewhere to go back to");

      await scrollTo(scroller, scroller.scrollHeight);
      assert
        .dom(JUMP)
        .doesNotExist("and returning to the bottom re-arms following");
    });

    /*
     * Releasing on scroll-up is the whole point: someone reading history must not
     * be dragged back down by an event arriving.
     */
    test("a row arriving does not move a detached reader", async function (assert) {
      const scroller = await overflowingTrace(this);
      await scrollTo(scroller, scroller.scrollHeight);
      await scrollTo(scroller, 0);

      const before = scroller.scrollTop;
      this.a11y.announce("arrived while reading", "polite");
      await settledAnnouncements();

      assert.strictEqual(
        scroller.scrollTop,
        before,
        "and the new row did not drag the reader down"
      );
      assert
        .dom(JUMP)
        .hasText(/\d/, "the control says how much has arrived unseen");
    });

    test("jumping returns to the newest row and re-engages following", async function (assert) {
      const scroller = await overflowingTrace(this);
      await scrollTo(scroller, scroller.scrollHeight);
      await scrollTo(scroller, 0);

      this.a11y.announce("arrived while reading", "polite");
      await settledAnnouncements();

      await click(JUMP);

      assert
        .dom(JUMP)
        .doesNotExist("back at the bottom, so the control has done its job");
      assert.true(
        scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight < 5,
        "and the newest row is in view"
      );
    });

    /*
     * Placed after the list, the control is invisible in exactly the case it exists
     * for — it would sit below the fold of the very scroller it is meant to bring
     * you back to. It lives inside the scroller so it can be pinned to its edge.
     */
    test("the jump control lives inside the scroller", async function (assert) {
      const scroller = await overflowingTrace(this);
      await scrollTo(scroller, scroller.scrollHeight);
      await scrollTo(scroller, 0);

      assert
        .dom(`${SCROLLER} ${JUMP}`)
        .exists("inside the scrollport, not appended after the list");
    });
  });

  /*
   * Oracle for the Inspector's information design (unit 3b).
   *
   * Utterance-first. The composed line a reader would say leads, because it is the
   * answer to the only question the panel exists to ask. Then the finding, if there
   * is one. Then the identity line. Then a fact grid holding only fields that are
   * set. Then the actions.
   *
   * What it replaces was four labelled groups that always rendered, so an ordinary
   * focus produced "CURSOR / state: absent" — a heading, a term and a value spent
   * saying that nothing was there.
   */
  module("Inspector detail (unit 3b)", function () {
    const INSPECTOR = ".dev-tools-a11y__inspector.--aside";
    const UTTERANCE = `${INSPECTOR} .dev-tools-a11y__inspector-utterance`;
    const FACTS = `${INSPECTOR} .dev-tools-a11y__inspector-facts`;

    async function inspecting(markup) {
      await render(markup);
      attachCapture();
    }

    /*
     * The non-negotiable the old design got wrong: the composed utterance is shown
     * for ANY focused element, not only when a cursor target exists. Most focus is
     * an ordinary control, and that is exactly when you want to know what would be
     * said.
     */
    test("the utterance leads, for a plain focused control", async function (assert) {
      await inspecting(
        <template>
          <button type="button" id="save" aria-label="Save draft">S</button>
          <A11yPanel />
        </template>
      );
      await focus("#save");

      assert
        .dom(UTTERANCE)
        .exists("a control with no cursor still has an utterance")
        .includesText("Save draft");

      const inspector = document.querySelector(INSPECTOR);
      const utterance = document.querySelector(UTTERANCE);
      assert.strictEqual(
        inspector.querySelector(":scope > *"),
        utterance,
        "and it is the first thing in the Inspector, not buried under a heading"
      );

      detachCapture();
    });

    test("a finding follows the utterance and carries its tier", async function (assert) {
      await inspecting(
        <template>
          <div
            id="dangling"
            role="listbox"
            aria-label="Categories"
            tabindex="0"
            aria-activedescendant="nowhere"
          ></div>
          <A11yPanel />
        </template>
      );
      await focus("#dangling");

      const message = document.querySelector(
        `${INSPECTOR} .dev-tools-a11y__inspector-message.--broken`
      );
      assert.dom(message).exists("the finding is stated, tinted by its tier");
      assert.strictEqual(
        document.querySelector(UTTERANCE).nextElementSibling,
        message,
        "immediately after the utterance it belongs to"
      );

      detachCapture();
    });

    /*
     * The old design's actual failure. A section with nothing to say must not
     * render at all, rather than being reworded into a tidier way of saying nothing.
     */
    test("nothing is said about what is not there", async function (assert) {
      await inspecting(
        <template>
          <button type="button" id="plain" aria-label="Reply">R</button>
          <A11yPanel />
        </template>
      );
      await focus("#plain");

      const text = document.querySelector(INSPECTOR).textContent;
      assert.false(
        /absent|none|n\/a|undefined/i.test(text),
        `no field reports its own emptiness, got ${text.trim()}`
      );

      const terms = [...document.querySelectorAll(`${FACTS} dt`)];
      const empty = terms.filter(
        (term) => !term.nextElementSibling?.textContent.trim()
      );
      assert.deepEqual(empty, [], "and no term is paired with an empty value");

      detachCapture();
    });

    // The name is in the utterance and in the identity line by construction. A third
    // copy as its own fact is the repetition this layout exists to remove.
    test("the accessible name is not repeated as a fact", async function (assert) {
      await inspecting(
        <template>
          <button type="button" id="named" aria-label="Publish">P</button>
          <A11yPanel />
        </template>
      );
      await focus("#named");

      assert.dom(UTTERANCE).includesText("Publish", "the utterance says it");
      assert.dom(FACTS).doesNotIncludeText("Publish", "the fact grid does not");

      detachCapture();
    });

    /*
     * Where unit 1d's weak handles finally have a consumer. The identity line
     * describes the element in strings; the control beside it hands back the node,
     * which is the ordinary devtools loop the panel was breaking.
     */
    test("the identity line offers the element itself", async function (assert) {
      await inspecting(
        <template>
          <button type="button" id="handled" aria-label="Reveal">R</button>
          <A11yPanel />
        </template>
      );
      await focus("#handled");

      assert
        .dom(`${INSPECTOR} .dev-tools-a11y__inspector-identity`)
        .exists("the element is named");

      const logged = sinon.stub(console, "log");
      try {
        await click(`${INSPECTOR} .dev-tools-a11y__inspector-log`);
        assert.strictEqual(
          logged.firstCall.args.at(-1),
          document.querySelector("#handled"),
          "and activating the control logs that exact node"
        );
      } finally {
        logged.restore();
      }

      detachCapture();
    });
  });

  /*
   * Two more for unit 3b, both from Codex's gap report and both about a value that
   * exists but reads as absent.
   */
  module("Inspector detail edges (unit 3b)", function () {
    const INSPECTOR = ".dev-tools-a11y__inspector.--aside";

    /*
     * A zero is a fact, not a missing one. `0` is falsy, so any "drop what is not
     * set" filter deletes it unless the value was stringified first — and "no options
     * are selected" is precisely what someone inspecting a multi-select wants to
     * know, being different from "this is not a multi-select".
     */
    test("a fact whose value is zero still renders", async function (assert) {
      await render(
        <template>
          <div
            id="multi"
            role="listbox"
            aria-label="Tags"
            aria-multiselectable="true"
            tabindex="0"
            aria-activedescendant="tag-one"
          >
            <div id="tag-one" role="option" aria-selected="false">One</div>
            <div id="tag-two" role="option" aria-selected="false">Two</div>
          </div>
          <A11yPanel />
        </template>
      );
      attachCapture();
      await focus("#multi");

      const facts = document.querySelector(
        `${INSPECTOR} .dev-tools-a11y__inspector-facts`
      );
      assert.dom(facts).exists("there are facts to read");
      assert
        .dom(facts)
        .includesText(
          i18n("dev_tools.a11y.facts.selected_in_list"),
          "none-selected is stated rather than dropped as falsy"
        );

      detachCapture();
    });

    /*
     * The other half of unit 1d's two states. Nothing is said about WHY a handle is
     * gone: collection timing is non-deterministic and carries no information about
     * the page, so an explanation would be noise dressed as diagnosis.
     */
    test("a row with no element to hand back offers no control", async function (assert) {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );
      attachLiveRegions();

      this.a11y.announce("nothing focused here", "polite");
      await settledAnnouncements();
      await click(".dev-tools-a11y__entry");

      assert
        .dom(`${INSPECTOR} .dev-tools-a11y__inspector-utterance`)
        .exists("the announcement is still described");
      assert
        .dom(`${INSPECTOR} .dev-tools-a11y__inspector-log`)
        .doesNotExist("but there is no node to offer, so no control");
      assert
        .dom(INSPECTOR)
        .doesNotIncludeText(
          "unavailable",
          "and no explanation of why, which would be noise"
        );
    });
  });

  /*
   * Oracle for the churn mute control (unit 3e, second half).
   *
   * Collapsing churn makes the rest of a capture readable; muting is for the region
   * you have already decided is not your problem. Two entrances, one control: Regions
   * is its home, but a developer buried in churn is looking at Trace, so selecting a
   * collapsed churn row opens that region in the Inspector with the control there.
   */
  module("churn mute (unit 3e)", function (muteHooks) {
    const MUTE = ".dev-tools-a11y__mute";

    // Its own hooks, not the outer module's: reaching the enclosing `hooks` through
    // the closure would register these on every test in the file.
    muteHooks.beforeEach(function () {
      this.hosts = [];
    });

    muteHooks.afterEach(function () {
      this.hosts?.forEach((host) => host.remove());
    });

    async function churning(context) {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );
      attachLiveRegions();

      const host = document.createElement("div");
      host.innerHTML = `<div id="churner" aria-live="polite"></div>`;
      document.body.appendChild(host);
      context.hosts.push(host);
      attachLiveRegions();

      /*
       * Churned by REPLACEMENT, not by removal. Removing it makes the region leave,
       * so it stops being watched and never appears in Regions — which is where the
       * control lives. A cycling extension replaces its region; it does not abandon
       * it, and the region has to still be there to be muted.
       */
      for (let cycle = 0; cycle < 3; cycle++) {
        const replacement = document.createElement("div");
        replacement.id = "churner";
        replacement.setAttribute("aria-live", "polite");
        host.querySelector("#churner").replaceWith(replacement);
        attachLiveRegions();
      }
      await settled();
    }

    /*
     * A panel that quietly stops reporting is the failure this whole rebuild exists to
     * undo. Muting hides the noise from the trace; it must never hide the fact that
     * something is being hidden.
     */
    test("a muted region stays visible in Regions, marked", async function (assert) {
      await churning(this);
      await click(".dev-tools-a11y__view.--regions");

      const row = () =>
        [...document.querySelectorAll(".dev-tools-a11y__region")].find((one) =>
          one.textContent.includes("churner")
        );

      assert.dom(row()).exists("listed to begin with");
      await click(row().querySelector(MUTE));

      assert
        .dom(row())
        .exists("still listed after muting, not quietly dropped")
        .hasClass("--muted", "and marked as muted");
    });

    // Regions is the control's home, but the developer who needs it is looking at
    // Trace. Selecting the churn row opens its region in the Inspector, where the
    // same control lives — which also keeps the churn row a single button, because a
    // control inside it would nest a button in a button.
    test("a churn row opens its region in the Inspector, with the control", async function (assert) {
      await churning(this);

      const noise = document.querySelector(".dev-tools-a11y__noise");
      assert.dom(noise).exists("the cycle collapsed");
      assert.strictEqual(
        noise.querySelector(MUTE),
        null,
        "the row itself nests no control, so it stays a single button"
      );

      await click(noise);

      assert
        .dom(`.dev-tools-a11y__inspector.--aside`)
        .includesText("churner", "the region is what the Inspector describes");
      assert
        .dom(`.dev-tools-a11y__inspector.--aside ${MUTE}`)
        .exists("and the control is reachable from here");
    });

    test("muting from the Trace marks the region the same as from Regions", async function (assert) {
      await churning(this);

      await click(document.querySelector(".dev-tools-a11y__noise"));
      await click(`.dev-tools-a11y__inspector.--aside ${MUTE}`);
      await click(".dev-tools-a11y__view.--regions");

      const row = [
        ...document.querySelectorAll(".dev-tools-a11y__region"),
      ].find((one) => one.textContent.includes("churner"));
      assert
        .dom(row)
        .hasClass("--muted", "one state, whichever entrance set it");
    });
  });

  /*
   * Oracle for the Sweep view (unit 3d).
   *
   * Aggregating by rule was the fix for the sweep that returned forty rows. But a
   * count with no way to reach an example is a dead end the moment you believe the
   * count — so a rule row expands to the elements behind it, collapsed by default,
   * and the forty rows only ever appear one rule at a time.
   *
   * Rejected: listing every element flat, which is the noise the aggregation exists
   * to prevent; and a "log all N" control with no visible list, which makes the
   * console the only place the answer exists.
   */
  module("Sweep view (unit 3d)", function () {
    const ROW = ".dev-tools-a11y__sweep-row";

    async function sweep(markup) {
      await render(markup);
      attachLiveRegions();
      await click(".dev-tools-a11y__view.--sweep");
      await click(".dev-tools-a11y__sweep-scan");
    }

    /*
     * The line that makes a clean result read as VERIFIED rather than as nothing
     * having run. Without it, an empty sweep and a broken sweep look identical.
     */
    test("a scan states what it checked", async function (assert) {
      await sweep(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );

      assert
        .dom(".dev-tools-a11y__sweep-scope")
        .hasText(
          /\d+/,
          "how much was examined, so a clean result is evidence rather than silence"
        );
      assert
        .dom(".dev-tools-a11y__sweep-clean")
        .exists("and a page with nothing wrong says so in words");
    });

    test("findings aggregate by rule, with a count", async function (assert) {
      await sweep(
        <template>
          <div id="one" role="alert" aria-live="polite"></div>
          <div id="two" role="alert" aria-live="polite"></div>
          <A11yPanel />
        </template>
      );

      assert
        .dom(ROW)
        .exists({ count: 1 }, "two elements breaking one rule is one row");
      assert
        .dom(`${ROW} .dev-tools-a11y__sweep-count`)
        .hasText("2", "carrying how many elements are behind it");
      assert
        .dom(`${ROW} .dev-tools-a11y__sweep-rule`)
        .hasText(
          "live.politeness-contradicts-role",
          "named by its stable id, so a pasted result is searchable"
        );
    });

    /*
     * Collapsed first, because the aggregation is what stopped the sweep being a wall
     * of rows — but reachable, because a count you cannot open is a dead end.
     */
    test("a rule row opens to the elements behind it", async function (assert) {
      await sweep(
        <template>
          <div id="one" role="alert" aria-live="polite"></div>
          <div id="two" role="alert" aria-live="polite"></div>
          <A11yPanel />
        </template>
      );

      assert
        .dom(ROW)
        .hasAttribute("aria-expanded", "false", "collapsed to begin with");
      assert
        .dom(".dev-tools-a11y__sweep-element")
        .doesNotExist("and its elements are not listed yet");

      await click(ROW);

      assert.dom(ROW).hasAttribute("aria-expanded", "true");
      assert
        .dom(".dev-tools-a11y__sweep-element")
        .exists(
          { count: 2 },
          "both elements behind the count are now reachable"
        );
    });

    // The same weak handle the Inspector uses. A description you cannot turn back
    // into a node leaves you grepping the page for it.
    test("an element behind a rule hands back its node", async function (assert) {
      await sweep(
        <template>
          <div id="one" role="alert" aria-live="polite"></div>
          <A11yPanel />
        </template>
      );
      await click(ROW);

      const logged = sinon.stub(console, "log");
      try {
        await click(
          ".dev-tools-a11y__sweep-element .dev-tools-a11y__sweep-log"
        );
        assert.strictEqual(
          logged.firstCall.args.at(-1),
          document.querySelector("#one"),
          "the exact element the count was counting"
        );
      } finally {
        logged.restore();
      }
    });
  });

  /*
   * Oracle for the Regions view (unit 3c).
   *
   * A region verdict is a property of the PAGE, not of an event, so it does not
   * belong in the timeline — recording them as rows put two rows on every page in
   * the product. They need their own surface, and this is also the only home a
   * NOTED region observation has.
   */
  module("Regions view (unit 3c)", function () {
    const REGION = ".dev-tools-a11y__region";

    async function regionsView(markup) {
      await render(markup);
      attachLiveRegions();
      await click(".dev-tools-a11y__view.--regions");
    }

    test("each watched region is listed with its channel and count", async function (assert) {
      await regionsView(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );

      this.a11y.announce("twelve results", "polite");
      await settledAnnouncements();

      const polite = [...document.querySelectorAll(REGION)].find((row) =>
        row.textContent.includes("a11y-announcements-polite")
      );
      assert.dom(polite).exists("the polite region is listed");
      assert
        .dom(polite)
        .includesText("polite", "with the channel it announces on");
      assert
        .dom(polite.querySelector(".dev-tools-a11y__region-count"))
        .hasText(/1/, "and how many deliveries it has made");
      assert
        .dom(polite)
        .includesText("twelve results", "and what it last delivered");
    });

    /*
     * The rule that ships broken in core today: `role="alert"` with
     * `aria-live="polite"` means the attribute wins, so the author wrote "alert" and
     * the user gets a queued announcement.
     */
    test("a region's verdict is stated with its severity", async function (assert) {
      await regionsView(
        <template>
          <div id="contradiction" role="alert" aria-live="polite"></div>
          <A11yPanel />
        </template>
      );

      const row = [...document.querySelectorAll(REGION)].find((one) =>
        one.textContent.includes("contradiction")
      );
      assert.dom(row).hasClass("--broken", "the row carries the severity");
      assert
        .dom(row.querySelector(".dev-tools-a11y__region-message.--broken"))
        .hasText(
          i18n("dev_tools.a11y.findings.live.politeness_contradicts_role"),
          "and says what is wrong in words"
        );
    });

    // A region the tree excludes can never announce, however correct its markup.
    test("a region outside the accessibility tree says so", async function (assert) {
      await regionsView(
        <template>
          <div
            id="hidden-region"
            aria-live="polite"
            style="display: none"
          ></div>
          <A11yPanel />
        </template>
      );

      const row = [...document.querySelectorAll(REGION)].find((one) =>
        one.textContent.includes("hidden-region")
      );
      assert
        .dom(row)
        .includesText(
          i18n("dev_tools.a11y.regions.out_of_tree"),
          "being unreachable is the first thing worth knowing about it"
        );
    });

    /*
     * The staleness the plan refuses to ship. Region facts are re-derived on each
     * discovery pass, and passes are driven by announcements and captured events —
     * so without watching the attributes themselves, a programmatic `role` change is
     * reported with its old value until something unrelated happens on the page.
     */
    test("an attribute change is reflected without waiting for unrelated activity", async function (assert) {
      await regionsView(
        <template>
          <div id="drifting" role="status" aria-live="polite"></div>
          <A11yPanel />
        </template>
      );

      const rowFor = () =>
        [...document.querySelectorAll(REGION)].find((one) =>
          one.textContent.includes("drifting")
        );

      assert
        .dom(rowFor())
        .doesNotHaveClass("--broken", "correct markup to begin with");

      document
        .querySelector("#drifting")
        .setAttribute("aria-live", "assertive");
      await settledAnnouncements();

      assert
        .dom(rowFor())
        .hasClass(
          "--broken",
          "a status region announcing assertively is reported as soon as it changes"
        );
    });

    // Settled in an earlier plan, after recording them as rows put two rows on
    // every page in the product.
    test("region verdicts never become timeline rows", async function (assert) {
      await render(
        <template>
          <div id="contradiction" role="alert" aria-live="polite"></div>
          <A11yPanel />
        </template>
      );
      attachLiveRegions();

      const verdicts = timelineEntries().flatMap((entry) =>
        entry.findings.map(({ id }) => id)
      );

      assert.false(
        verdicts.includes("live.politeness-contradicts-role"),
        "the verdict is a property of the page, not something that happened"
      );
    });
  });

  /*
   * Oracle for the Inspector's two positions (unit 3a).
   *
   * CSS cannot move DOM, so a container query cannot relocate one Inspector: it can
   * only choose which of two rendered copies is shown. Past a wide-enough container
   * the detail is a side panel; below it, a block beneath the selected row.
   *
   * `display: none` removes a subtree from the accessibility tree AND the tab order,
   * so the hidden copy costs correctness nothing — but two copies of the same markup
   * must not duplicate `id` attributes, and the state they render has to live in the
   * component rather than in either copy's DOM.
   *
   * Which copy is VISIBLE is not asserted here. Visibility is a container query, the
   * panel's stylesheet is not reliably loaded in qunit, and a computed-style
   * assertion would pass or fail for reasons unrelated to the markup. That half is a
   * system spec, at two real dock widths, in `dev_tools_a11y_panel_spec.rb`.
   */
  module("Inspector placement (unit 3a)", function () {
    const INSPECTOR = ".dev-tools-a11y__inspector";

    async function panelWithSelection(context) {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );
      attachLiveRegions();

      context.a11y.announce("twelve results", "polite");
      await settledAnnouncements();
    }

    test("the Inspector is rendered once for each position", async function (assert) {
      await panelWithSelection(this);

      assert
        .dom(`${INSPECTOR}.--aside`)
        .exists({ count: 1 }, "the side copy, for a wide container");
      assert
        .dom(`${INSPECTOR}.--inline`)
        .exists({ count: 1 }, "and the inline copy, for a narrow one");
    });

    /*
     * The hazard of rendering the same markup twice. A duplicate id makes every
     * `aria-labelledby`, `aria-describedby` and `for` inside the copies ambiguous —
     * which in the accessibility panel would be its own punchline.
     */
    test("the copies duplicate no ids", async function (assert) {
      await panelWithSelection(this);

      const ids = [...document.querySelectorAll(".dev-tools-a11y [id]")].map(
        (element) => element.id
      );
      const duplicated = ids.filter((id, index) => ids.indexOf(id) !== index);

      assert.deepEqual(duplicated, [], "no id appears twice in the panel");
    });

    // Both copies read the same component state. If either kept its own, the two
    // would disagree the moment the container crossed the threshold.
    test("both copies describe the same selection", async function (assert) {
      await panelWithSelection(this);

      const texts = [...document.querySelectorAll(INSPECTOR)].map((copy) =>
        copy.textContent.includes("twelve results")
      );

      assert.strictEqual(texts.length, 2, "there are two copies to compare");
      assert.deepEqual(
        texts,
        [true, true],
        "and both are describing the same selection"
      );
    });

    /*
     * "Beneath the selected row" is the whole claim of the inline position. A copy
     * appended at the end of the list would satisfy every other test here while
     * describing a row the reader has to go looking for.
     */
    test("the inline copy sits immediately after the row it describes", async function (assert) {
      await panelWithSelection(this);

      await click(".dev-tools-a11y__entry");

      const selected = document.querySelector(
        ".dev-tools-a11y__entry.--selected"
      );
      assert.dom(selected).exists("a row is selected");

      const inline = document.querySelector(`${INSPECTOR}.--inline`);
      assert.strictEqual(
        selected.closest("li").nextElementSibling,
        inline.closest("li"),
        "the detail is the very next item, not appended after the list"
      );
    });

    /*
     * The container declaration itself is NOT asserted here, deliberately. Nothing in
     * the tree declared one before this unit, and a container query with no container
     * silently never matches — so it genuinely needs covering. But it is CSS, and the
     * only way to check it from here would be a marker attribute mirroring the
     * stylesheet, which would drift from the thing it claims to prove. The system
     * spec's visibility assertions cannot pass unless the container exists, which
     * covers it against the real cascade instead.
     */
  });

  /*
   * Oracle for the density map (unit 2e).
   *
   * The map is the only affordance that reports findings OUTSIDE the viewport,
   * which is a situation a scrolling live log creates constantly. It shows the
   * whole retained ring rather than the rendered rows, with one mark per finding
   * and the current viewport boxed.
   *
   * These tests await a frame, unlike unit 2d's. That is not a workaround: whether
   * the list overflows is a POST-LAYOUT fact. It cannot be known during render, and
   * reading `scrollHeight` at render time would thrash layout on every append. So a
   * `ResizeObserver` writes a tracked flag, and a ResizeObserver fires at a
   * rendering opportunity that `settled()` does not await. Following, by contrast,
   * is driven by row data and needs no frame — that difference is the point.
   */
  module("density map (unit 2e)", function () {
    const MAP = ".dev-tools-a11y__map";
    const MARK = ".dev-tools-a11y__map-mark";

    /** Layout has happened and any observation of it has been applied. */
    async function afterLayout() {
      await new Promise((resolve) => requestAnimationFrame(resolve));
      await settled();
    }

    async function traceWithFindings(context) {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
          <button type="button" id="echo" aria-describedby="echo-desc">
            Save
          </button>
          <span id="echo-desc">Save</span>
          <div
            id="dangling"
            role="listbox"
            aria-label="Categories"
            tabindex="0"
            aria-activedescendant="nowhere"
          ></div>
          {{! A noted observation rather than a defect: the authored position
              disagrees with the DOM, which these attributes exist precisely to
              do. A title-duplicates-name fixture would have been simpler, but
              eslint rejects that markup in a template, which is itself the
              plan's point about lint already covering the static cases. }}
          <div
            id="noted"
            role="listbox"
            aria-label="Sizes"
            tabindex="0"
            aria-activedescendant="noted-option"
          >
            <div
              id="noted-option"
              role="option"
              aria-posinset="5"
              aria-setsize="9"
            >
              Medium
            </div>
          </div>
        </template>
      );
      attachLiveRegions();
      attachCapture();

      // An announcement between each focus keeps them from collapsing into one
      // run, so their findings land at different places in the ring.
      await focus("#echo");
      context.a11y.announce("between", "polite");
      await settledAnnouncements();
      await focus("#dangling");
      context.a11y.announce("and between again", "polite");
      await settledAnnouncements();
      await focus("#noted");

      for (let index = 0; index < 6; index++) {
        context.a11y.announce(`filler ${index}`, "polite");
        await settledAnnouncements();
      }

      return document.querySelector(".dev-tools-a11y__scroller");
    }

    /*
     * Both halves in one test. Its entire job is pointing at what you cannot see,
     * so a list that fits has nothing for it to point at — and asserting only the
     * absence would pass on a panel that never renders a map at all.
     */
    test("the map appears only once the list overflows", async function (assert) {
      const scroller = await traceWithFindings(this);

      scroller.style.height = "";
      await afterLayout();
      assert.dom(MAP).doesNotExist("nothing to point at while it all fits");

      scroller.style.height = "40px";
      scroller.style.overflowY = "auto";
      await afterLayout();

      assert.true(
        scroller.scrollHeight > scroller.clientHeight,
        "the fixture really overflows"
      );
      assert.dom(MAP).exists("and now there is something below the fold");
    });

    /*
     * The map marks what RANKS, which is not the same as what was observed. A
     * `noted` observation is true but not a defect — it never colours a row and it
     * does not feed the Problems filter — so a mark for one is a 3px element with no
     * background: invisible, and pure noise on a strip whose whole purpose is
     * pointing at problems.
     */
    test("the ring is marked for what ranks, and nothing else", async function (assert) {
      const scroller = await traceWithFindings(this);
      scroller.style.height = "40px";
      scroller.style.overflowY = "auto";
      await afterLayout();

      const ranked = document.querySelectorAll(
        ".dev-tools-a11y__entry-message.--broken, .dev-tools-a11y__entry-message.--fragile"
      ).length;
      const noted = document.querySelectorAll(
        ".dev-tools-a11y__entry-message.--noted"
      ).length;

      assert.true(ranked > 1, "the fixture produced several ranked findings");
      assert.true(noted > 0, "and at least one that does not rank");
      assert
        .dom(MARK)
        .exists(
          { count: ranked },
          "one mark per ranked finding, including those out of view"
        );
      assert.true(
        [...document.querySelectorAll(MARK)].every(
          (mark) =>
            mark.classList.contains("--broken") ||
            mark.classList.contains("--fragile")
        ),
        "and every mark carries a severity, so none of them is invisible"
      );
    });

    // Positioned by where the finding sits in the ring, which is what makes the
    // strip a map rather than a legend.
    test("marks sit at the position of what they mark", async function (assert) {
      const scroller = await traceWithFindings(this);
      scroller.style.height = "40px";
      scroller.style.overflowY = "auto";
      await afterLayout();

      const offsets = [...document.querySelectorAll(MARK)].map(
        (mark) => mark.style.top
      );

      // Asserted non-empty first: an empty list satisfies `every` and makes the
      // distinctness check trivially true, so no marks at all would pass both.
      assert.true(offsets.length > 1, "there are several marks to place");
      assert.true(
        offsets.every((top) => /%$/.test(top)),
        `each mark is placed proportionally, got ${offsets.join(", ")}`
      );
      assert.strictEqual(
        new Set(offsets).size,
        offsets.length,
        "and two findings at different places do not stack"
      );
    });

    /*
     * The map covers the retained RING, not the rendered rows, so narrowing the
     * list must not narrow the map — that is the constraint that stops the shared
     * projection from being "fixed" into showing only filtered rows.
     *
     * The filter is chosen to keep the list overflowing while excluding every row
     * that carries a finding. Filtering down to a list that FITS would remove the
     * map altogether, which is correct behaviour and would prove nothing here.
     */
    test("narrowing the list does not narrow the map", async function (assert) {
      const scroller = await traceWithFindings(this);
      scroller.style.height = "40px";
      scroller.style.overflowY = "auto";
      await afterLayout();

      const before = document.querySelectorAll(MARK).length;
      assert.true(before > 1, "there are marks to begin with");

      await fillIn(".dev-tools-a11y__toolbar input", "filler");
      await afterLayout();

      assert
        .dom(".dev-tools-a11y__entry-message")
        .doesNotExist("the rows carrying findings are filtered out");
      assert.strictEqual(
        document.querySelectorAll(MARK).length,
        before,
        "yet the map still reports every finding in the ring"
      );
    });

    test("the viewport is boxed on the map", async function (assert) {
      const scroller = await traceWithFindings(this);
      scroller.style.height = "40px";
      scroller.style.overflowY = "auto";
      await afterLayout();

      assert
        .dom(".dev-tools-a11y__map-viewport")
        .exists("what is on screen is drawn against what is not");
    });

    /*
     * Every finding the map marks is already present as row text in the same list,
     * all 200 of them, so a reader using assistive technology loses nothing by the
     * map being hidden — and an unlabelled decorative strip in the accessibility
     * tree is exactly the noise this panel exists to find.
     */
    test("the map is hidden from assistive technology", async function (assert) {
      const scroller = await traceWithFindings(this);
      scroller.style.height = "40px";
      scroller.style.overflowY = "auto";
      await afterLayout();

      assert.dom(MAP).hasAttribute("aria-hidden", "true");
    });
  });

  /*
   * Oracle for the row grammar (unit 2b).
   *
   * Four channels, each carrying exactly one thing: the rail is severity, the
   * gutter is what you did, the line is what a reader would say, the right margin
   * is when. Background is never any of them — it means selection and nothing
   * else, which is what the previous three competing tints got wrong.
   *
   * The utterance leads because it answers the only question the panel exists to
   * ask, so it is the one thing in the body face at full size while everything
   * else is monospace and recedes.
   */
  module("row grammar (unit 2b)", function () {
    async function panelWithAnnouncement(context, channel = "polite") {
      await render(
        <template>
          <A11yLiveRegions />
          <A11yPanel />
        </template>
      );
      attachLiveRegions();

      context.a11y.announce("twelve results", channel);
      await settledAnnouncements();
    }

    function rowText() {
      return [...document.querySelectorAll(".dev-tools-a11y__entry")]
        .map((row) => row.textContent)
        .join(" ");
    }

    test("a row carries all four channels", async function (assert) {
      await panelWithAnnouncement(this);

      const row = document.querySelector(".dev-tools-a11y__entry");
      for (const channel of ["rail", "cause", "say", "meta"]) {
        assert
          .dom(row.querySelector(`.dev-tools-a11y__entry-${channel}`))
          .exists(`the ${channel} channel`);
      }
    });

    /*
     * The merge that the whole grammar is built around. Two rows printed the same
     * sentence twice and added nothing — but the row has to keep BOTH markers,
     * because a dozen assertions and the system page object select on them and a
     * new third class would break every one silently.
     */
    test("an announcement and its delivery are one row keeping both markers", async function (assert) {
      await panelWithAnnouncement(this);

      const merged = document.querySelectorAll(
        ".dev-tools-a11y__entry.--intent.--delivered"
      );
      assert.strictEqual(merged.length, 1, "one row, carrying both markers");
      assert.strictEqual(
        rowText().match(/twelve results/g).length,
        1,
        "and the sentence appears once"
      );
    });

    // Which region a write landed in is what proves the announcement went out on
    // the channel it asked for. The grammar has no channel of its own for it, so
    // it rides the dim annotation beside the sentence.
    test("a delivery names the region it landed in", async function (assert) {
      await panelWithAnnouncement(this, "assertive");

      const dim = [
        ...document.querySelectorAll(".dev-tools-a11y__entry-dim"),
      ].map((element) => element.textContent);
      assert.true(
        dim.some((text) => text.includes("a11y-announcements-assertive")),
        `the delivering region is named, got ${dim.join(" | ")}`
      );
    });

    /*
     * A real capture is mostly silent rows, so silence needs a shape to scan for
     * rather than a word to read. The blank is a ruled element with no text.
     */
    test("silence is a ruled blank, not a word", async function (assert) {
      await render(
        <template>
          <input id="typed" aria-label="Search" />
          <A11yPanel />
        </template>
      );
      attachCapture();
      await focus("#typed");

      const silent = document.querySelector(".dev-tools-a11y__entry-silent");
      assert.dom(silent).exists("a row that announced nothing draws a rule");
      assert.strictEqual(
        silent.textContent.trim(),
        "",
        "and says nothing, because there is nothing to say"
      );

      detachCapture();
    });

    /*
     * A finding is the only two-line row shape: a second line beneath its own
     * sentence, full width, in a block carrying its own tint. The rail states the
     * severity and the block repeats it, and the pinned hooks ride the block so
     * the page object keeps working.
     */
    test("a finding is a second line under its own sentence", async function (assert) {
      await render(
        <template>
          <div aria-live="polite"></div>
          <A11yPanel />
        </template>
      );
      attachLiveRegions();

      this.a11y.announce("no results", "polite");
      await settledAnnouncements();

      const row = document.querySelector(".dev-tools-a11y__entry.--broken");
      assert.dom(row).exists("the rail states the severity on the row");
      assert
        .dom(row.querySelector(".dev-tools-a11y__entry-message.--broken"))
        .exists("and the sentence beneath it carries the same tint");
      assert
        .dom(row.querySelector(".dev-tools-a11y__problem"))
        .exists("the problem hook the page object selects on survives");
    });

    // Latency measures the announcement, so it belongs with the sentence. The
    // margin means one thing everywhere — the gap since the previous row — and a
    // second duration in it would make the column ambiguous.
    test("latency sits with the sentence and the margin keeps the sequence", async function (assert) {
      await panelWithAnnouncement(this);

      const row = document.querySelector(
        ".dev-tools-a11y__entry.--intent.--delivered"
      );
      assert
        .dom(
          row.querySelector(
            ".dev-tools-a11y__entry-say .dev-tools-a11y__entry-latency"
          )
        )
        .exists("latency rides the line, not the margin");
      assert
        .dom(
          row.querySelector(
            ".dev-tools-a11y__entry-meta .dev-tools-a11y__entry-seq"
          )
        )
        .exists("and the margin carries the sequence");
    });

    /*
     * A burst recedes to the noise floor: same shape, less ink. It states its
     * range and its count and nothing else, because there is no honest summary of
     * sixty-six elements.
     */
    /*
     * The margin is permanent, so its format is load-bearing: a separator between
     * the two quantities, and a unit that changes with magnitude because 90 ms is
     * a script and 1.2 s is a person. Reading `1200 ms` forces that arithmetic on
     * every row.
     */
    test("the margin separates sequence from elapsed and scales the unit", async function (assert) {
      await panelWithAnnouncement(this);

      // A second announcement, because elapsed is the gap from the PREVIOUS row,
      // and the first row of a capture correctly has none to report.
      this.a11y.announce("and again", "polite");
      await settledAnnouncements();

      const meta = [
        ...document.querySelectorAll(".dev-tools-a11y__entry-meta"),
      ].at(-1);
      assert
        .dom(meta)
        .hasText(/#\d+(–\d+)? · /, "sequence, separator, elapsed");
      assert.dom(meta).doesNotIncludeText("+", "the margin is not a delta");

      assert.strictEqual(
        i18n("dev_tools.a11y.duration_ms", { value: 90 }),
        "90 ms",
        "sub-second reads in milliseconds"
      );
      assert.strictEqual(
        i18n("dev_tools.a11y.duration_s", { value: "1.2" }),
        "1.2 s",
        "and a second or more reads in seconds"
      );
    });

    // Latency is a delta and the margin is not, so the sign is what tells them
    // apart at a glance when both are on the same row.
    test("latency is signed", async function (assert) {
      await panelWithAnnouncement(this);

      assert
        .dom(".dev-tools-a11y__entry-latency")
        .hasText(/^\+\d/, "the announcement's own duration carries its sign");
    });

    /*
     * Churn is grouped BY region identity, so naming it generically throws away
     * the only thing that distinguishes one extension's noise from another's —
     * and two regions cycling at once become indistinguishable rows.
     */
    test("a churn group is named by the region it is about", async function (assert) {
      await render(<template><A11yPanel /></template>);
      attachLiveRegions();

      const host = document.createElement("div");
      host.innerHTML = `<div id="churner" aria-live="polite"></div>`;
      document.body.appendChild(host);

      try {
        attachLiveRegions();
        host.querySelector("#churner").remove();
        attachLiveRegions();
        await settled();

        const noise = document.querySelector(".dev-tools-a11y__noise");
        assert.dom(noise).exists("the cycle collapses to one row");
        assert.true(
          noise.textContent.includes("churner"),
          `named by its region, got ${noise.textContent.trim()}`
        );
        // Churn is a region, not a run: selecting it opens that region rather
        // than disclosing members, so it must not advertise a control it has
        // no semantics for.
        assert
          .dom(noise)
          .doesNotHaveAttribute(
            "aria-expanded",
            "a churn row is not a disclosure"
          );
      } finally {
        host.remove();
      }
    });

    test("a collapsed run recedes and states only its range and count", async function (assert) {
      await render(
        <template>
          <button type="button" id="one">one</button>
          <button type="button" id="two">two</button>
          <button type="button" id="three">three</button>
          <A11yPanel />
        </template>
      );
      attachCapture();
      await focus("#one");
      await focus("#two");
      await focus("#three");

      const noise = document.querySelector(".dev-tools-a11y__noise");
      assert.dom(noise).exists("the burst is one row on the noise floor");
      assert
        .dom(noise.querySelector(".dev-tools-a11y__noise-range"))
        .hasText(/#\d+–\d+/, "its range, with one hash");
      assert.true(
        /\S\s*×\s*3\b/.test(noise.textContent),
        `the count follows what it counts, got ${noise.textContent.trim()}`
      );

      // The noise floor is its own shape — a flex row, not the four-column grid —
      // so a row cannot be both without one display rule silently beating the
      // other depending on which lands later in a stylesheet nothing lints.
      assert
        .dom(noise)
        .doesNotHaveClass(
          "dev-tools-a11y__entry",
          "a noise row is not also a grid row"
        );

      detachCapture();
    });

    /*
     * A collapsed run has to be openable, or collapsing is destruction: the
     * utterances of its members are the answer to the only question the panel
     * exists to ask, and a row that hides them with no way back is worse than the
     * density it buys.
     */
    async function captureRun() {
      await render(
        <template>
          <button type="button" id="one" aria-label="First">one</button>
          <button type="button" id="two" aria-label="Second">two</button>
          <button type="button" id="three" aria-label="Third">three</button>
          <A11yPanel />
        </template>
      );
      attachCapture();
      await focus("#one");
      await focus("#two");
    }

    /*
     * Members are asserted through their own container, never by index into all
     * rows. Watching the regions records a meta row of its own, which IS an entry
     * row, so an unscoped `[0]` reaches that instead of a member and the test
     * passes without opening anything.
     */
    const MEMBERS = ".dev-tools-a11y__run-members";

    test("a collapsed run opens to show its members", async function (assert) {
      await captureRun();

      const run = document.querySelector(".dev-tools-a11y__noise");
      assert
        .dom(run)
        .hasAttribute("aria-expanded", "false", "closed to begin with");
      assert.dom(MEMBERS).doesNotExist("and its members are not rows yet");

      await click(run);

      assert
        .dom(".dev-tools-a11y__noise")
        .hasAttribute("aria-expanded", "true");
      assert
        .dom(MEMBERS)
        .exists("the members are disclosed in their own container");
      assert
        .dom(`${MEMBERS} .dev-tools-a11y__entry`)
        .exists({ count: 2 }, "both members become rows of their own");

      detachCapture();
    });

    // Opening is a display state, not a selection change. The run row is the thing
    // carrying the control, so the selection stays on it until a member is
    // deliberately picked — otherwise opening silently changes what the Inspector
    // is describing.
    test("opening a run leaves the selection on the run", async function (assert) {
      await captureRun();

      await click(document.querySelector(".dev-tools-a11y__noise"));

      assert.dom(MEMBERS).exists("it did open");
      assert
        .dom(".dev-tools-a11y__noise.--selected")
        .exists("and the run is still what is selected");
      assert
        .dom(`${MEMBERS} .dev-tools-a11y__entry.--selected`)
        .doesNotExist("opening picked no member");

      detachCapture();
    });

    /*
     * The reason open state is keyed by `row.id` rather than by position or by
     * extent. A run grows while it is being read, so every new event re-projects
     * the list — and a run that closed under the reader on each new event would be
     * unusable during exactly the live capture the panel is for.
     */
    test("an open run stays open as it grows", async function (assert) {
      await captureRun();

      await click(document.querySelector(".dev-tools-a11y__noise"));
      assert.dom(MEMBERS).exists("open to begin with");

      await focus("#three");

      assert
        .dom(".dev-tools-a11y__noise")
        .hasAttribute("aria-expanded", "true", "still open one event later");
      assert
        .dom(`${MEMBERS} .dev-tools-a11y__entry`)
        .exists({ count: 3 }, "and the new member is disclosed with the rest");

      detachCapture();
    });

    test("picking a member of an open run selects that member", async function (assert) {
      await captureRun();

      await click(document.querySelector(".dev-tools-a11y__noise"));
      await click(document.querySelector(`${MEMBERS} .dev-tools-a11y__entry`));

      assert
        .dom(`${MEMBERS} .dev-tools-a11y__entry.--selected`)
        .exists({ count: 1 }, "from then on it is an ordinary row selection");
      assert
        .dom(".dev-tools-a11y__noise.--selected")
        .doesNotExist("and the selection has left the run");

      detachCapture();
    });
  });
});
