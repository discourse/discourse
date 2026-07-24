import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  settled,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

const OPTION_SELECTOR = "ul[role='listbox'] > [role='option']";

function buildItems(count, captureEngine) {
  return Array.from({ length: count }, (_, index) => ({
    id: index + 1,
    name: `Item ${index + 1}`,
    ...(index === 0 && captureEngine
      ? { onSelect: (engine) => captureEngine(engine) }
      : {}),
  }));
}

async function openSelect() {
  await click("[role='combobox']");
}

module(
  "Integration | ui-kit | select | DSelect reveal and set metadata",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a client list renders every row with its true set metadata", async function (assert) {
      // 210 exceeds the retired 200-row client cap, so a rendered count of 210 proves the
      // engine no longer bounds the client list (DVirtualList windows the DOM elsewhere).
      const items = buildItems(210);

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();

      const options = findAll(OPTION_SELECTOR);
      assert.strictEqual(
        options.length,
        210,
        "every client row renders, past the retired cap"
      );
      assert
        .dom(".d-combobox__narrow")
        .doesNotExist("a fully rendered client list never pins a cap");
      assert
        .dom(options[0])
        .hasAttribute("aria-posinset", "1", "the first row occupies position 1")
        .hasAttribute(
          "aria-setsize",
          "210",
          "the first row exposes the true client total"
        );
      assert
        .dom(options[209])
        .hasAttribute(
          "aria-posinset",
          "210",
          "the last row occupies the final position"
        )
        .hasAttribute("aria-setsize", "210", "the set size is the whole list");
    });

    test("a fully rendered small client list keeps its set metadata", async function (assert) {
      const items = buildItems(3);

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();

      assert
        .dom(OPTION_SELECTOR)
        .exists({ count: 3 }, "all small-list rows render");
      assert
        .dom(`${OPTION_SELECTOR}:last-child`)
        .hasAttribute(
          "aria-posinset",
          "3",
          "the last row has its true position"
        )
        .hasAttribute("aria-setsize", "3", "the small-list total is exposed");
    });

    test("a capped server list shows and announces the keep-filtering hint", async function (assert) {
      // The cap survives for a SERVER source only: its accumulator stops at MAX_RENDERED while
      // the source still holds more, which is the one path that raises the narrow hint. (A
      // client source renders in full and never caps — see the client tests above.)
      let engine;
      const a11y = getOwner(this).lookup("service:a11y");
      const announce = sinon.spy(a11y, "announce");
      const allItems = buildItems(500, (value) => (engine = value));
      const load = (_filter, { offset = 0 }) => ({
        items: allItems.slice(offset, offset + 50),
        total: allItems.length,
      });

      await render(
        <template><DSelect @load={{load}} @debounce={{false}} /></template>
      );
      await openSelect();
      await click(findAll(OPTION_SELECTOR)[0]);

      for (let index = 0; index < 6; index++) {
        engine.revealMore();
        await settled();
      }

      assert
        .dom(OPTION_SELECTOR)
        .exists({ count: 200 }, "the server accumulator fills the cap");
      assert
        .dom(".d-virtual-list + .d-combobox__narrow[role='status']")
        .exists("the filter-to-narrow hint follows the capped list viewport");
      assert
        .dom("ul[role='listbox'] .d-combobox__narrow")
        .doesNotExist("the hint is never an invalid listbox child");
      assert.true(
        announce
          .getCalls()
          .some(
            ({ args }) =>
              args[0] === i18n("d_select.filter_to_narrow") &&
              args[1] === "polite"
          ),
        "the hint is announced through the a11y service"
      );
    });

    test("a filter change re-renders a client list without pinning a cap", async function (assert) {
      const items = buildItems(210);

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();
      assert
        .dom(OPTION_SELECTOR)
        .exists({ count: 210 }, "the whole client list renders");
      assert
        .dom(".d-combobox__narrow")
        .doesNotExist("a full client list never shows the narrow hint");

      // "Item 42" is a unique substring in a 1..210 list (Item 420-429 do not exist).
      await fillIn("[role='combobox']", "Item 42");

      assert
        .dom(OPTION_SELECTOR)
        .exists({ count: 1 }, "the filter narrows the rendered list");
      assert
        .dom(".d-combobox__narrow")
        .doesNotExist("filtering a client list never pins a cap");
    });

    // A source that declares no paging is taken to have returned the whole set, so its row
    // count is a truthful `aria-setsize` rather than the -1 unknown-size encoding.
    test("a bare-array server source exposes an exact set size", async function (assert) {
      const load = () => buildItems(3);

      await render(
        <template><DSelect @load={{load}} @debounce={{false}} /></template>
      );
      await openSelect();

      assert
        .dom(OPTION_SELECTOR)
        .exists({ count: 3 }, "the server rows render");
      findAll(OPTION_SELECTOR).forEach((option, index) => {
        assert
          .dom(option)
          .hasAttribute("aria-setsize", "3", "silence sized the set")
          .hasAttribute("aria-posinset", String(index + 1));
      });
    });

    test("the create row has no position when the set size is unknown", async function (assert) {
      // Unknown size now requires a source that is actively mid-paging: it has told us more
      // exists without saying how much.
      const load = () => ({ items: buildItems(2), hasMore: true });
      const createItem = (filter) => ({ id: `new:${filter}`, name: filter });

      await render(
        <template>
          <DSelect
            @load={{load}}
            @debounce={{false}}
            @allowCreate={{true}}
            @createItem={{createItem}}
          />
        </template>
      );
      await fillIn("[role='combobox']", "Something new");

      const createRow = findAll(OPTION_SELECTOR).at(-1);
      assert.dom(createRow).hasText(/Something new/, "the create row is last");
      // It is appended after an unknown number of source rows, so unlike a prefix row its
      // slot genuinely cannot be derived.
      assert
        .dom(createRow)
        .hasAttribute("aria-setsize", "-1")
        .doesNotHaveAttribute(
          "aria-posinset",
          "the appended create row has no derivable slot in an unsized set"
        );
    });

    test("a partially-loaded server response reports an unknown set size", async function (assert) {
      const allItems = buildItems(500);
      const load = (_filter, { offset = 0 }) => ({
        items: allItems.slice(offset, offset + 50),
        total: allItems.length,
      });

      await render(
        <template><DSelect @load={{load}} @debounce={{false}} /></template>
      );
      await openSelect();

      const options = findAll(OPTION_SELECTOR);
      assert.strictEqual(options.length, 50, "the first server page renders");
      assert
        .dom(options[49])
        .hasAttribute("aria-posinset", "50", "the page tail has position 50")
        .hasAttribute(
          "aria-setsize",
          "-1",
          "a source that declares 500 but has loaded 50 cannot honestly size its set — the reader can only reach loaded rows, so the size stays unknown until it completes"
        );
    });

    // A cursor source knows there is more without knowing how many. The set size must stay
    // honestly unknown while it pages, then become exact the moment the source declares
    // completeness — through the template, not merely on the getter: a value already read in
    // a render has to be invalidated to reach the DOM.
    test("a cursor source's set size stays unknown until it declares completeness", async function (assert) {
      let engine;
      const allItems = buildItems(5, (value) => (engine = value));
      const load = (_filter, { offset = 0 }) =>
        offset === 0
          ? { items: allItems.slice(0, 3), hasMore: true }
          : { items: allItems.slice(3, 5), hasMore: false };

      await render(
        <template><DSelect @load={{load}} @debounce={{false}} /></template>
      );
      await openSelect();
      await click(findAll(OPTION_SELECTOR)[0]);

      assert
        .dom(findAll(OPTION_SELECTOR)[0])
        .hasAttribute(
          "aria-setsize",
          "-1",
          "a source still paging cannot size its set"
        );

      engine.revealMore();
      await settled();

      const options = findAll(OPTION_SELECTOR);
      assert.strictEqual(options.length, 5, "the final page is mounted");
      options.forEach((option, index) => {
        assert
          .dom(option)
          .hasAttribute(
            "aria-setsize",
            "5",
            "completeness re-renders every row with the real set size"
          )
          .hasAttribute("aria-posinset", String(index + 1));
      });
    });

    test("completing a cursor source announces the real count, not the loaded count", async function (assert) {
      let engine;
      const announce = sinon.spy(
        getOwner(this).lookup("service:a11y"),
        "announce"
      );
      const allItems = buildItems(5, (value) => (engine = value));
      const load = (_filter, { offset = 0 }) =>
        offset === 0
          ? { items: allItems.slice(0, 3), hasMore: true }
          : { items: allItems.slice(3, 5), hasMore: false };

      await render(
        <template><DSelect @load={{load}} @debounce={{false}} /></template>
      );
      await openSelect();
      await click(findAll(OPTION_SELECTOR)[0]);

      assert.strictEqual(
        announce.withArgs(
          i18n("d_select.results_loaded", { count: 3 }),
          "polite"
        ).callCount,
        1,
        "an unsized source announces only what it has loaded"
      );

      engine.revealMore();
      await settled();

      assert.strictEqual(
        announce.withArgs(
          i18n("d_select.results_count", { count: 5 }),
          "polite"
        ).callCount,
        1,
        "the final page announces the true result count"
      );
    });

    test("a held server reveal makes the retained listbox busy and announces its transitions", async function (assert) {
      let engine;
      let releaseReveal;
      let revealRequested = false;
      const a11y = getOwner(this).lookup("service:a11y");
      const announce = sinon.spy(a11y, "announce");
      const allItems = buildItems(500, (value) => (engine = value));
      const revealPromise = new Promise((resolve) => (releaseReveal = resolve));
      const load = (_filter, { offset = 0 }) => {
        if (offset === 0) {
          return { items: allItems.slice(0, 50), total: allItems.length };
        }

        revealRequested = true;
        return revealPromise;
      };

      await render(
        <template><DSelect @load={{load}} @debounce={{false}} /></template>
      );
      await openSelect();
      await click(findAll(OPTION_SELECTOR)[0]);

      const initialAnnouncements = announce.callCount;
      engine.revealMore();
      await waitUntil(() => revealRequested);

      assert
        .dom("ul[role='listbox']")
        .hasAttribute(
          "aria-busy",
          "true",
          "the already-rendered listbox becomes busy while reveal is held"
        );
      assert.true(
        announce
          .getCalls()
          .slice(initialAnnouncements)
          .some(
            ({ args }) =>
              typeof args[0] === "string" &&
              /loading more/i.test(args[0]) &&
              args[1] === "polite"
          ),
        "server reveal announces loading more through the a11y service"
      );

      releaseReveal({ items: allItems.slice(50, 100), total: allItems.length });
      await settled();

      const busy = find("ul[role='listbox']").getAttribute("aria-busy");
      assert.true(
        [null, "false"].includes(busy),
        "aria-busy clears after the held reveal settles"
      );
      assert.true(
        announce
          .getCalls()
          .some(
            ({ args }) =>
              typeof args[0] === "string" &&
              /loaded/i.test(args[0]) &&
              args[1] === "polite"
          ),
        "server reveal announces completion through the a11y service"
      );
    });

    test("special and create rows keep flat positions around the source rows", async function (assert) {
      const items = buildItems(5);
      const specialItems = () => [
        { id: "all", name: "All items" },
        { id: "none", name: "No item" },
      ];
      const createItem = (filter) => ({
        id: `create-${filter}`,
        name: `Create ${filter}`,
        __create: true,
      });

      await render(
        <template>
          <DSelect
            @items={{items}}
            @specialItems={{specialItems}}
            @allowCreate={{true}}
            @createItem={{createItem}}
          />
        </template>
      );
      await fillIn("[role='combobox']", "Item");

      // Two specials, all five source rows, then the create row: 8 rows, all rendered.
      const options = findAll(OPTION_SELECTOR);
      assert.strictEqual(
        options.length,
        8,
        "specials, every source row, and the create row all render"
      );
      assert
        .dom(options[0])
        .hasText("All items", "special rows remain prepended")
        .hasAttribute("aria-posinset", "1", "the first special owns slot 1")
        .hasAttribute("aria-setsize", "8", "synthetic rows join the true set");
      assert
        .dom(options[2])
        .hasText("Item 1", "source rows follow the specials")
        .hasAttribute(
          "aria-posinset",
          "3",
          "the source offset includes specials"
        );
      assert
        .dom(options[7])
        .hasClass("--create", "the create row is appended last")
        .hasAttribute(
          "aria-posinset",
          "8",
          "the create row owns the true final slot"
        )
        .hasAttribute(
          "aria-setsize",
          "8",
          "the create row shares the true set size"
        );
    });

    test("the result count announces the true total and a client reveal never re-announces", async function (assert) {
      let engine;
      const announce = sinon.spy(
        getOwner(this).lookup("service:a11y"),
        "announce"
      );
      const items = buildItems(60, (value) => (engine = value));
      const trueCountMessage = i18n("d_select.results_count", { count: 60 });

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();
      await click(findAll(OPTION_SELECTOR)[0]);

      assert.strictEqual(
        announce.withArgs(trueCountMessage, "polite").callCount,
        1,
        "opening announces the true client total"
      );

      assert.false(engine.revealMore(), "a client reveal is an inert no-op");
      await settled();

      assert.strictEqual(
        announce.withArgs(trueCountMessage, "polite").callCount,
        1,
        "the inert reveal does not re-announce the unchanged total"
      );
    });

    test("a held server reveal shows skeleton rows below the mounted options", async function (assert) {
      let engine;
      let releaseReveal;
      let revealRequested = false;
      const allItems = buildItems(500, (value) => (engine = value));
      const revealPromise = new Promise((resolve) => (releaseReveal = resolve));
      const load = (_filter, { offset = 0 }) => {
        if (offset === 0) {
          return { items: allItems.slice(0, 50), total: allItems.length };
        }
        revealRequested = true;
        return revealPromise;
      };

      await render(
        <template><DSelect @load={{load}} @debounce={{false}} /></template>
      );
      await openSelect();
      await click(findAll(OPTION_SELECTOR)[0]);
      assert
        .dom("ul[role='listbox'] .d-combobox__skeleton")
        .doesNotExist("a settled list shows no placeholder rows");

      engine.revealMore();
      await waitUntil(() => revealRequested);

      // Released in `finally`: a throwing assertion would otherwise leave the load pending,
      // hanging teardown until the qunit timeout and poisoning the next test.
      try {
        // Retained rows plus a placeholder for the page in flight: without this the list just
        // stops with no sighted feedback, since aria-busy is only exposed to assistive tech.
        assert
          .dom(OPTION_SELECTOR)
          .exists({ count: 50 }, "the already-loaded rows stay mounted");
        assert
          .dom("ul[role='listbox'] .d-combobox__skeleton")
          .doesNotExist(
            "a source that answers quickly never flashes a placeholder"
          );

        // Only a load slow enough to read as stuck earns visible feedback.
        await waitUntil(() =>
          document.querySelector("ul[role='listbox'] .d-combobox__skeleton")
        );
        const skeletons = findAll("ul[role='listbox'] .d-combobox__skeleton");
        assert.true(
          skeletons.length > 0,
          "placeholder rows mark the pending page"
        );
        assert
          .dom(skeletons[0])
          .hasAttribute(
            "aria-hidden",
            "true",
            "placeholders are hidden from AT"
          )
          // A listbox admits only option and group children, so a bare list item would be
          // an invalid child even though aria-hidden already removes it from the tree.
          .hasAttribute(
            "role",
            "presentation",
            "placeholders carry no list semantics"
          );
        assert.false(
          skeletons.some((el) => el.matches("[role='option']")),
          "placeholders never enter the roving-focus option set"
        );
      } finally {
        releaseReveal({
          items: allItems.slice(50, 100),
          total: allItems.length,
        });
        await settled();
      }

      assert
        .dom("ul[role='listbox'] .d-combobox__skeleton")
        .doesNotExist("placeholders clear once the page lands");
      assert.dom(OPTION_SELECTOR).exists({ count: 100 }, "the page appended");
    });

    test("reopening the list announces the result count again", async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      const announce = sinon.spy(a11y, "announce");
      const items = buildItems(60);
      const message = i18n("d_select.results_count", { count: 60 });

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();
      assert.strictEqual(
        announce.withArgs(message, "polite").callCount,
        1,
        "opening announces the count"
      );

      await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
      assert.dom("ul[role='listbox']").doesNotExist("the overlay closed");
      await openSelect();

      // A fresh listbox is a fresh context: the count describes what just appeared, so the
      // dedupe from the previous open must not silence it.
      assert.strictEqual(
        announce.withArgs(message, "polite").callCount,
        2,
        "reopening announces the count again"
      );
    });

    test("a new query is not announced as loading more results", async function (assert) {
      let releaseQuery;
      const a11y = getOwner(this).lookup("service:a11y");
      const announce = sinon.spy(a11y, "announce");
      const allItems = buildItems(500);
      let calls = 0;
      const load = () => {
        calls++;
        if (calls === 1) {
          return { items: allItems.slice(0, 50), total: allItems.length };
        }
        return new Promise((resolve) => (releaseQuery = resolve));
      };

      await render(
        <template><DSelect @load={{load}} @debounce={{false}} /></template>
      );
      await openSelect();

      const before = announce.callCount;
      // Deliberately un-awaited: `fillIn` settles the runloop, which would block on the
      // held promise. The point is to observe the mid-flight state.
      const querying = fillIn("[role='combobox']", "Item 4");
      await waitUntil(() => Boolean(releaseQuery));

      const during = announce.getCalls().slice(before);
      // A re-query also holds the old rows and also reads as pending, but it is a
      // replacement, not more results — and its rows/total are stale until it lands.
      assert.false(
        during.some(({ args }) => /loading more/i.test(String(args[0]))),
        "a replacement query never announces loading more"
      );
      assert.false(
        during.some(({ args }) => /result/i.test(String(args[0]))),
        "the retained previous rows are never announced as the new count"
      );

      releaseQuery({ items: allItems.slice(0, 7), total: 7 });
      await querying;
      await settled();

      assert.true(
        announce
          .getCalls()
          .slice(before)
          .some(({ args }) => /7 results/i.test(String(args[0]))),
        "the settled query announces its own true count"
      );
    });
  }
);
