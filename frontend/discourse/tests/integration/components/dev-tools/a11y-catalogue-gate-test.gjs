import { focus, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import { ruleIds, tierOf } from "discourse/static/dev-tools/a11y/findings";
// Namespace import on purpose: a named import of something not yet exported
// fails at link time and takes the whole module down, which reads as a broken
// suite rather than as an assertion failing.
import * as instrumentation from "discourse/static/dev-tools/a11y/instrumentation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/**
 * The catalogue gate.
 *
 * Every registered rule is held to a PAIR of fixtures: one it must fire on, and
 * one near-miss it must stay silent on. A rule that only ever fires is not a
 * rule, it is a stuck alarm, and that is precisely how the previous version of
 * this panel failed — it flagged every icon button named by its `title` and
 * every control inside a dialog, so the Problems filter ranked nothing.
 *
 * The `quiet` half is the half that matters and the half that is easy to fake.
 * A quiet fixture that differs from its `fires` twin in some obvious, unrelated
 * way proves nothing: the rule could be keying off the difference rather than
 * off the defect. Each pair below is therefore as close to its twin as the rule
 * allows, and where the near-miss is subtle the reason is written down.
 *
 * A rule with no detector yet is registered here as a `todo`. QUnit fails a
 * `todo` that starts passing, so the detector landing forces this file to be
 * updated rather than letting the pair rot unnoticed.
 */

/** Fixtures the focus-driven rules share, so each pair states only its variable. */
const LISTBOX = (items, attrs = "") =>
  `<div id="subject" role="listbox" tabindex="0" aria-label="Categories" ${attrs}>${items}</div>`;

const CATALOGUE = [
  {
    id: "focus.not-in-tree",
    fires: {
      html: `<div aria-hidden="true"><button id="subject">Go</button></div>`,
      focus: true,
    },
    // Same shape, same wrapper, opposite value. A rule keying off the presence
    // of the attribute rather than its value fails here.
    quiet: {
      html: `<div aria-hidden="false"><button id="subject">Go</button></div>`,
      focus: true,
    },
  },
  {
    id: "focus.no-name",
    fires: { html: `<button id="subject"></button>`, focus: true },
    // The same button, named. Swapping in a role that does not require a name
    // would also be quiet, but it would test the role conjunct instead of name
    // computation, so a detector that flags every empty button would pass.
    quiet: { html: `<button id="subject">Save</button>`, focus: true },
  },
  {
    id: "cursor.dangling",
    fires: {
      html: LISTBOX(
        `<div id="opt-1" role="option">Bugs</div>`,
        `aria-activedescendant="missing"`
      ),
      focus: true,
    },
    quiet: {
      html: LISTBOX(
        `<div id="opt-1" role="option">Bugs</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
  },
  {
    id: "cursor.target-hidden",
    fires: {
      html: LISTBOX(
        `<div id="opt-1" role="option" style="display:none">Bugs</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
    // Present, resolvable, and off-screen rather than out of the tree —
    // `clip` is how a visually-hidden but readable row is built.
    quiet: {
      html: LISTBOX(
        `<div id="opt-1" role="option" style="position:absolute;clip:rect(0 0 0 0)">Bugs</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
  },
  {
    id: "cursor.not-item",
    // Same composite, same target element, same position in the tree. Only the
    // target's role changes, so a detector scoped to listboxes-with-role=option
    // cannot pass by ignoring everything else.
    fires: {
      html: LISTBOX(
        `<div id="opt-1" role="group">Bugs</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
    quiet: {
      html: LISTBOX(
        `<div id="opt-1" role="option">Bugs</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
  },
  {
    id: "cursor.claim-missing",
    // An unowned target is also not reachable as an item of the composite, so
    // both verdicts are true of the same markup. Declared rather than filtered:
    // the point of the strict assertion is that nothing gets to be invisible.
    firesAlso: ["cursor.not-item"],
    fires: {
      html: `<div id="subject" role="listbox" tabindex="0" aria-label="Categories" aria-activedescendant="opt-1"></div>
             <div id="opt-1" role="option">Bugs</div>`,
      focus: true,
    },
    // Outside the container too, but claimed through `aria-owns`, which is the
    // normative way to own a descendant that is not a DOM descendant.
    //
    // KNOWN GAP, pinned here rather than hidden: item classification does not
    // follow `aria-owns`, so a correctly-owned option is still reported as not
    // being an item of its composite. That is noise on correct markup and wants
    // fixing, but it is a product change rather than part of this gate.
    quietAlso: ["cursor.not-item"],
    quiet: {
      html: `<div id="subject" role="listbox" tabindex="0" aria-label="Categories"
                  aria-owns="opt-1" aria-activedescendant="opt-1"></div>
             <div id="opt-1" role="option">Bugs</div>`,
      focus: true,
    },
  },
  {
    id: "cursor.visual-diverged",
    fires: {
      html: LISTBOX(
        `<div id="opt-1" role="option">Bugs</div><div id="opt-2" role="option" data-active-descendant>Features</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
    quiet: {
      html: LISTBOX(
        `<div id="opt-1" role="option" data-active-descendant>Bugs</div><div id="opt-2" role="option">Features</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
  },
  {
    id: "cursor.visual-diverged-conventional",
    fires: {
      html: LISTBOX(
        `<div id="opt-1" role="option">Bugs</div><div id="opt-2" role="option" class="--active">Features</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
    // The same conventional marker, on the row the cursor actually points at.
    // Using the contract case here instead would never exercise the comparison,
    // so a detector that fires on the mere presence of `--active` would pass.
    quiet: {
      html: LISTBOX(
        `<div id="opt-1" role="option" class="--active">Bugs</div><div id="opt-2" role="option">Features</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
  },
  {
    id: "set.impossible",
    // Position beyond the authored set size, with the set size and the DOM held
    // constant against the quiet half. A detector checking only `posinset < 1`
    // fails here, which the previous fixture let it survive.
    fires: {
      html: LISTBOX(
        `<div id="opt-1" role="option" aria-posinset="41" aria-setsize="40">Bugs</div><div role="option">Features</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
    // Authored values that override a two-item DOM. This is what the attributes
    // are FOR, and a virtualised list produces it constantly — so it is
    // legitimately `set.disagrees`, which is NOTED and stays out of the filter.
    quietAlso: ["set.disagrees"],
    quiet: {
      html: LISTBOX(
        `<div id="opt-1" role="option" aria-posinset="7" aria-setsize="40">Bugs</div><div role="option">Features</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
  },
  {
    id: "set.disagrees",
    fires: {
      html: LISTBOX(
        `<div id="opt-1" role="option" aria-posinset="7" aria-setsize="40">Bugs</div><div role="option">Features</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
    quiet: {
      html: LISTBOX(
        `<div id="opt-1" role="option" aria-posinset="1" aria-setsize="2">Bugs</div><div role="option">Features</div>`,
        `aria-activedescendant="opt-1"`
      ),
      focus: true,
    },
  },
  {
    id: "role.missing-state",
    fires: {
      html: `<div id="subject" role="checkbox" tabindex="0" aria-label="Watch"></div>`,
      focus: true,
    },
    // The host language supplies `checked`, so ARIA does not have to.
    // The explicit role is essential: without it `requiredAttributeFindings`
    // returns before the native-semantics carve-out runs, so deleting that
    // carve-out would leave this green.
    quiet: {
      html: `<input id="subject" type="checkbox" role="checkbox" aria-label="Watch" />`,
      focus: true,
    },
  },
  {
    id: "role.missing-attribute",
    // The popup exists in BOTH halves, so a detector that merely notices a
    // listbox on the page cannot pass. Only `aria-controls` varies.
    fires: {
      html: `<div id="subject" role="combobox" tabindex="0" aria-label="Category"
                  aria-expanded="true"></div>
             <ul id="popup" role="listbox" aria-label="Categories"></ul>`,
      focus: true,
    },
    // The same expanded combobox with the attribute supplied. Note the rule has
    // no carve-out for a COLLAPSED combobox, where APG allows omitting
    // `aria-controls` — the tier already carries that uncertainty, which is why
    // this one is FRAGILE and stays out of the problems filter.
    quiet: {
      html: `<div id="subject" role="combobox" tabindex="0" aria-label="Category"
                  aria-expanded="true" aria-controls="popup"></div>
             <ul id="popup" role="listbox" aria-label="Categories"></ul>`,
      focus: true,
    },
  },
  {
    id: "role.missing-attribute-defaulted",
    fires: {
      html: `<div id="subject" role="heading" tabindex="0">Latest</div>`,
      focus: true,
    },
    // Explicitly roled for the same reason as the checkbox above: the native
    // level has to be reached through the carve-out, not by skipping the check.
    quiet: {
      html: `<h2 id="subject" role="heading" tabindex="0">Latest</h2>`,
      focus: true,
    },
  },
  {
    id: "name.describedby-echoes-name",
    fires: {
      html: `<button id="subject" aria-describedby="d">Admin</button><span id="d">Admin</span>`,
      focus: true,
    },
    // The same button with the same explicit description, saying something the
    // name does not already say. Only the description text varies, so a
    // detector that merely notices `aria-describedby` cannot pass. An anchor
    // titled with its own text would also be quiet, but only because it trips a
    // different rule, which proves nothing about this one.
    quiet: {
      html: `<button id="subject" aria-describedby="d">Admin</button><span id="d">Opens the admin area</span>`,
      focus: true,
    },
  },
  {
    id: "name.from-title-only",
    fires: {
      html: `<button id="subject" title="Close"></button>`,
      focus: true,
    },
    // Named by its content, with a title that says something else — so the
    // name did not come from the title, and the title is not a duplicate of it
    // either. Reusing the title as the visible text would be quiet only by
    // tripping the sibling rule instead.
    quiet: {
      html: `<button id="subject" title="Dismiss this dialog">Close</button>`,
      focus: true,
    },
  },
  {
    id: "name.title-duplicates-name",
    fires: {
      html: `<a id="subject" href="#" title="Admin">Admin</a>`,
      focus: true,
    },
    quiet: {
      html: `<a id="subject" href="#" title="Site settings">Admin</a>`,
      focus: true,
    },
  },
  {
    id: "name.labelledby-partly-unresolved",
    // The computed name comes out EMPTY when one idref does not resolve, so the
    // nameless rule fires alongside. That contradicts the assumption that a
    // surviving token supplies the whole name, and is worth pinning here rather
    // than discovering later.
    firesAlso: ["focus.no-name"],
    fires: {
      html: `<button id="subject" aria-labelledby="a missing"></button><span id="a">Save</span>`,
      focus: true,
    },
    // The SAME idref list, with the second element present. A detector keying on
    // the literal token or on how many label nodes exist cannot pass.
    quiet: {
      html: `<button id="subject" aria-labelledby="a missing"></button><span id="a">Save</span><span id="missing">draft</span>`,
      focus: true,
    },
  },
  {
    id: "live.born-with-content",
    region: `<div id="live-fixture" aria-live="polite">Already here</div>`,
    quietRegion: `<div id="live-fixture" aria-live="polite"></div>`,
  },
  {
    id: "live.born-with-content-alert",
    // A region is only considered against an intent on its OWN channel, so this
    // pair has to be announced assertively or neither half is looked at.
    channel: "assertive",
    // `role="alert"` with a matching `aria-live` is also the belt-and-braces
    // pairing, which is NOTED and true of this fixture at the same time.
    firesAlso: ["live.redundant-politeness"],
    region: `<div id="live-fixture" role="alert" aria-live="assertive">Already here</div>`,
    // Identical but for the role, which makes this the BROKEN `born-with-content`
    // instead. `role="alert"` is special-cased because it may raise a platform
    // alert event on insertion, and that varies by assistive technology.
    quietAlso: ["live.born-with-content"],
    quietRegion: `<div id="live-fixture" aria-live="assertive">Already here</div>`,
  },
  {
    id: "live.not-in-tree",
    region: `<div id="live-fixture" aria-live="polite" style="display:none"></div>`,
    quietRegion: `<div id="live-fixture" aria-live="polite"></div>`,
  },
  {
    id: "live.politeness-contradicts-role",
    region: `<div id="live-fixture" role="alert" aria-live="polite"></div>`,
    // A role and a politeness that agree, on the SAME channel as the fires
    // half — keeping the announced channel constant, so neither half is skipped
    // for a reason unrelated to the rule. Agreement is the belt-and-braces
    // pairing, which is NOTED and true here.
    quietAlso: ["live.redundant-politeness"],
    quietRegion: `<div id="live-fixture" role="status" aria-live="polite"></div>`,
  },
  {
    id: "live.redundant-politeness",
    region: `<div id="live-fixture" role="status" aria-live="polite"></div>`,
    quietRegion: `<div id="live-fixture" role="status"></div>`,
  },
];

module(
  "Integration | Component | dev-tools | a11y-catalogue-gate",
  function (hooks) {
    setupRenderingTest(hooks);

    let fixtures;

    hooks.beforeEach(function () {
      fixtures = [];
      this.a11y = this.owner.lookup("service:a11y");
      disableClearA11yAnnouncementsInTests();
      instrumentation.installA11yTap();
    });

    hooks.afterEach(function () {
      fixtures.forEach((fixture) => fixture.remove());
      instrumentation.resetA11yInstrumentation();
      enableClearA11yAnnouncementsInTests();
    });

    function addFixture(html) {
      const host = document.createElement("div");
      host.innerHTML = html;
      document.body.appendChild(host);
      fixtures.push(host);

      return host;
    }

    const unique = (ids) => [...new Set(ids)].sort();

    function reported() {
      const rowed = instrumentation
        .timelineEntries()
        .flatMap((entry) => entry.findings.map(({ id }) => id));
      const regions = (instrumentation.liveRegionFindings?.() ?? []).map(
        ({ id }) => id
      );

      return [...rowed, ...regions];
    }

    /**
     * Both halves of a pair use the same ids on purpose, since that is what
     * makes them near-misses. So the previous half has to leave the document
     * entirely before the next one arrives: left in place, `#subject` and
     * `#opt-1` resolve to the wrong fixture and every id-following rule reports
     * on markup the test is not looking at.
     */
    function clearFixtures() {
      fixtures.forEach((fixture) => fixture.remove());
      fixtures = [];
      instrumentation.resetA11yInstrumentation();
      // The reset uninstalls the announce tap, so without this every
      // intent-correlated rule goes quiet and its half of the pair looks like a
      // missing detector rather than a missing tap.
      instrumentation.installA11yTap();
    }

    async function runFocus(html) {
      clearFixtures();
      const host = addFixture(html);
      instrumentation.attachCapture();
      await focus(host.querySelector("#subject"));

      return reported();
    }

    async function runRegion(html, channel = "polite") {
      clearFixtures();
      // Watch an empty document FIRST, so the fixture below arrives rather than
      // being part of the baseline. Several of these rules are about what a
      // region looked like when it turned up, which a baseline scan cannot see.
      instrumentation.attachLiveRegions();
      addFixture(html);
      // Deliberately NOT watched again here. `announce` rediscovers the
      // document, so the fixture is seen as a region that JOINED — which is the
      // only way a rule about what a region looked like on arrival can fire.
      // Watching it first makes it part of the baseline and the arrival is lost.
      this.a11y.announce("results updated", channel);
      await settled();
      await Promise.resolve();
      await settled();

      // Every region fixture in this table is an inert placeholder that nothing
      // ever writes to, so the announcement above always misses its deadline.
      // That verdict is about the harness rather than about the markup under
      // test, and `announce.undelivered` has its own pair in the announcement
      // oracle, so it is dropped here rather than declared on all five rows.
      return reported().filter((id) => id !== "announce.undelivered");
    }

    for (const entry of CATALOGUE) {
      const { id } = entry;

      test(`${id} fires on its own fixture and stays quiet on its near-miss`, async function (assert) {
        const run = entry.region ? runRegion.bind(this) : runFocus;
        const firesHtml = entry.region ?? entry.fires.html;
        const quietHtml = entry.quietRegion ?? entry.quiet.html;

        const onFires = await run(firesHtml, entry.channel);
        const onQuiet = await run(quietHtml, entry.channel);

        // Asserting only that THIS id is absent would let a near-miss be as
        // noisy as it likes under a sibling rule, which is the same failure in
        // a new costume: correct markup that still lights the panel up. So each
        // half declares its complete finding set, and anything a fixture
        // legitimately also produces has to be written down as `firesAlso` or
        // `quietAlso` rather than passing unnoticed.
        assert.deepEqual(
          unique(onFires),
          unique([id, ...(entry.firesAlso ?? [])]),
          `${id} fires on the case it exists for, and nothing else does`
        );
        assert.deepEqual(
          unique(onQuiet),
          unique(entry.quietAlso ?? []),
          `the near-miss for ${id} is silent, or the filter ranks nothing`
        );
      });
    }

    /*
     * The gate is only as complete as its table, so a rule added to the registry
     * without a pair has to fail here rather than simply going unguarded.
     *
     * The five rules below are not exempt from being paired — they are paired in
     * the announcement oracle, which owns the intent-and-delivery correlation
     * this table has no shape for. Each is named with the pair that covers it, so
     * "owned elsewhere" cannot quietly become "covered nowhere". That was a real
     * risk: `announce.text-mismatch` sat in this list as a permanent waiver until
     * its detector landed, and nothing here would have noticed.
     */
    const OWNED_BY_ANNOUNCE_ORACLE = {
      "announce.no-region": "announcing with nowhere to land",
      "announce.undelivered": "an intent that never arrives",
      "announce.runaway": "the same message over and over",
      "announce.text-mismatch": "delivered text that differs from the intent",
      "live.replaced-mid-session": "a region replaced after it has delivered",
    };

    test("every registered rule is covered by a pair or a named owner", function (assert) {
      const paired = new Set(CATALOGUE.map(({ id }) => id));

      assert.deepEqual(
        ruleIds().filter(
          (id) => !paired.has(id) && !(id in OWNED_BY_ANNOUNCE_ORACLE)
        ),
        [],
        "no rule is registered without either a pair here or a named owner"
      );
    });

    test("every paired rule keeps the tier it was reviewed at", function (assert) {
      const REVIEWED = {
        "focus.not-in-tree": "broken",
        "focus.no-name": "broken",
        "cursor.dangling": "broken",
        "cursor.target-hidden": "broken",
        "cursor.not-item": "broken",
        "cursor.claim-missing": "fragile",
        "cursor.visual-diverged": "broken",
        "cursor.visual-diverged-conventional": "noted",
        "set.impossible": "broken",
        "set.disagrees": "noted",
        "role.missing-state": "broken",
        "role.missing-attribute": "fragile",
        "role.missing-attribute-defaulted": "noted",
        "name.describedby-echoes-name": "fragile",
        "name.from-title-only": "noted",
        "name.title-duplicates-name": "noted",
        "name.labelledby-partly-unresolved": "noted",
        "live.born-with-content": "broken",
        "live.born-with-content-alert": "fragile",
        "live.not-in-tree": "broken",
        "live.politeness-contradicts-role": "broken",
        "live.redundant-politeness": "noted",
      };

      // Asserting the tier is merely REGISTERED would pass a rule silently
      // promoted from noted to broken, which is how a filter fills up with
      // things that are true but are not defects.
      assert.deepEqual(
        CATALOGUE.map(({ id }) => `${id}=${tierOf(id)}`),
        CATALOGUE.map(({ id }) => `${id}=${REVIEWED[id]}`),
        "each paired rule still sits at the tier it was reviewed at"
      );
    });
  }
);
