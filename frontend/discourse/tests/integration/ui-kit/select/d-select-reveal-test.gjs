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
  "Integration | ui-kit | select | DSelect bounded reveal",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a large client list mounts one bounded window with true set metadata", async function (assert) {
      const items = buildItems(5000);

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();

      const options = findAll(OPTION_SELECTOR);
      assert.strictEqual(
        options.length,
        50,
        "only the first client chunk renders"
      );
      assert
        .dom(".d-combobox__narrow")
        .doesNotExist("the first window is not yet pinned at the cap");
      assert
        .dom(options[0])
        .hasAttribute("aria-posinset", "1", "the first row occupies position 1")
        .hasAttribute(
          "aria-setsize",
          "5000",
          "the first row exposes the true client total"
        );
      assert
        .dom(options[49])
        .hasAttribute(
          "aria-posinset",
          "50",
          "the last mounted row occupies position 50"
        )
        .hasAttribute(
          "aria-setsize",
          "5000",
          "the mounted window never masquerades as the whole set"
        );
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

    test("revealMore invalidates the rendered client window from 50 to 100", async function (assert) {
      let engine;
      const items = buildItems(5000, (value) => (engine = value));

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();
      assert
        .dom(OPTION_SELECTOR)
        .exists({ count: 50 }, "the initial render is one chunk");

      await click(findAll(OPTION_SELECTOR)[0]);
      assert.true(engine.revealMore(), "the engine accepts the next reveal");
      await settled();

      assert
        .dom(OPTION_SELECTOR)
        .exists({ count: 100 }, "tracked reveal growth reaches the real DOM");
    });

    test("client reveal is pinned at 200 and shows the narrow hint", async function (assert) {
      let engine;
      const items = buildItems(5000, (value) => (engine = value));

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();
      await click(findAll(OPTION_SELECTOR)[0]);

      for (let index = 0; index < 6; index++) {
        engine.revealMore();
        await settled();
      }

      assert
        .dom(OPTION_SELECTOR)
        .exists({ count: 200 }, "rendered source rows never exceed the cap");
      assert
        .dom(".d-virtual-list + .d-combobox__narrow[role='status']")
        .exists("the filter-to-narrow hint follows the capped list viewport");
      assert
        .dom("ul[role='listbox'] .d-combobox__narrow")
        .doesNotExist("the hint is never an invalid listbox child");
    });

    test("a filter change resets the rendered window and reveal affordances", async function (assert) {
      let engine;
      const items = buildItems(5000, (value) => (engine = value));

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();
      await click(findAll(OPTION_SELECTOR)[0]);

      for (let index = 0; index < 3; index++) {
        engine.revealMore();
        await settled();
      }

      assert
        .dom(".d-combobox__narrow")
        .exists("the unfiltered list reaches the narrow-at-cap state");

      await fillIn("[role='combobox']", "Item");

      assert
        .dom(OPTION_SELECTOR)
        .exists(
          { count: 50 },
          "filtering resets the rendered window to one chunk"
        );
      assert
        .dom(".d-combobox__narrow")
        .doesNotExist("the reset window is no longer at the cap");
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

    test("an object server response exposes its reported total", async function (assert) {
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
          "500",
          "the response total, not the page length, sizes the set"
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

    test("special and create rows stay outside the source cap with flat positions", async function (assert) {
      let engine;
      const items = buildItems(5000);
      const specialItems = () => [
        {
          id: "all",
          name: "All items",
          onSelect: (value) => (engine = value),
        },
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
      await click(findAll(OPTION_SELECTOR)[0]);

      for (let index = 0; index < 3; index++) {
        engine.revealMore();
        await settled();
      }

      const options = findAll(OPTION_SELECTOR);
      assert.strictEqual(
        options.length,
        203,
        "two specials and one create row remain visible around 200 source rows"
      );
      assert
        .dom(options[0])
        .hasText("All items", "special rows remain prepended")
        .hasAttribute("aria-posinset", "1", "the first special owns slot 1")
        .hasAttribute(
          "aria-setsize",
          "5003",
          "synthetic rows join the true set"
        );
      assert
        .dom(options[2])
        .hasText("Item 1", "source rows follow the specials")
        .hasAttribute(
          "aria-posinset",
          "3",
          "the source offset includes specials"
        );
      assert
        .dom(options[202])
        .hasClass(
          "--create",
          "the create row remains appended beyond the source cap"
        )
        .hasAttribute(
          "aria-posinset",
          "5003",
          "the create row owns the true final slot"
        )
        .hasAttribute(
          "aria-setsize",
          "5003",
          "the create row shares the true set size"
        );
    });

    test("result-count announcements use the true total and ignore reveal growth", async function (assert) {
      let engine;
      const announce = sinon.spy(
        getOwner(this).lookup("service:a11y"),
        "announce"
      );
      const items = buildItems(5000, (value) => (engine = value));
      const trueCountMessage = i18n("d_select.results_count", { count: 5000 });
      const windowCountMessage = i18n("d_select.results_count", { count: 100 });

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();
      await click(findAll(OPTION_SELECTOR)[0]);

      assert.strictEqual(
        announce.withArgs(trueCountMessage, "polite").callCount,
        1,
        "opening announces the true client total"
      );

      engine.revealMore();
      await settled();

      assert.strictEqual(
        announce.withArgs(trueCountMessage, "polite").callCount,
        1,
        "reveal growth does not re-announce an unchanged total"
      );
      assert.strictEqual(
        announce.withArgs(windowCountMessage, "polite").callCount,
        0,
        "the rendered window size is never announced as the result count"
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

    test("reaching the cap announces the keep-filtering hint", async function (assert) {
      let engine;
      const a11y = getOwner(this).lookup("service:a11y");
      const announce = sinon.spy(a11y, "announce");
      const items = buildItems(5000, (value) => (engine = value));

      await render(<template><DSelect @items={{items}} /></template>);
      await openSelect();
      await click(findAll(OPTION_SELECTOR)[0]);

      for (let index = 0; index < 6; index++) {
        engine.revealMore();
        await settled();
      }

      assert.dom(".d-combobox__narrow").exists("the list is pinned at the cap");
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

    test("reopening the list announces the result count again", async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      const announce = sinon.spy(a11y, "announce");
      const items = buildItems(5000);
      const message = i18n("d_select.results_count", { count: 5000 });

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
