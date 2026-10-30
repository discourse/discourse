import { tracked } from "@glimmer/tracking";
import { trackedObject } from "@ember/reactive/collections";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { disableThrowingApplyExceptionOnTests } from "discourse/lib/transformer";
import SelectEngine from "discourse/ui-kit/select/select-engine";

const ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
];

/** Registers one `select-customizations` callback that receives the registry. */
function customize(register) {
  withPluginApi((api) =>
    api.registerValueTransformer("select-customizations", ({ value }) => {
      register(value);
    })
  );
}

/** A content step that appends a marker row. */
function add(id) {
  return (spec) => spec.content((items) => [...items, { id, name: id }]);
}

/** Builds a select; reads as a statement where only its setups matter. */
function create(opts) {
  return new SelectEngine(opts);
}

function values(engine, items = []) {
  return engine.buildItems(items).map((row) => row.value);
}

/** A single select whose emitted changes are recorded. */
function controlled(opts = {}) {
  const changes = [];
  const engine = new SelectEngine({
    items: ITEMS,
    getValue: () => null,
    onChange: (value) => changes.push(value),
    ...opts,
  });
  return { engine, changes };
}

module("Unit | ui-kit | select-customizations", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.reported = [];
    this.onError = (event) => this.reported.push(event.detail);
    document.addEventListener("discourse-error", this.onError);
  });

  hooks.afterEach(function () {
    document.removeEventListener("discourse-error", this.onError);
  });

  module("targeting", function () {
    test("each tier reaches only its own targets", function (assert) {
      customize((selects) => {
        selects.forAll(add("all"));
        selects.forKind("tag-chooser", add("kind"));
        selects.forIdentifier("composer-tags", add("identifier"));
      });

      assert.deepEqual(
        values(new SelectEngine({})),
        ["all"],
        "an unnamed select gets only forAll"
      );
      assert.deepEqual(
        values(new SelectEngine({ kind: "tag-chooser" })),
        ["all", "kind"],
        "a kind gets forKind"
      );
      assert.deepEqual(
        values(new SelectEngine({ identifier: "composer-tags" })),
        ["all", "identifier"],
        "an identifier gets forIdentifier"
      );
      assert.deepEqual(
        values(create({ kind: "tag-chooser", identifier: "composer-tags" })),
        ["all", "kind", "identifier"],
        "both names get both tiers"
      );
      assert.deepEqual(
        values(create({ kind: "composer-tags", identifier: "tag-chooser" })),
        ["all"],
        "a kind never matches forIdentifier and an identifier never matches forKind"
      );
      assert.deepEqual(
        values(new SelectEngine({ kind: "tag-chooser-extra" })),
        ["all"],
        "names match exactly"
      );
    });

    test("tiers compose general to specific, in registration order within a tier", function (assert) {
      customize((selects) => {
        selects.forIdentifier("i", add("identifier-1"));
        selects.forKind("k", add("kind-1"));
        selects.forAll(add("all-1"));
      });
      customize((selects) => {
        selects.forIdentifier("i", add("identifier-2"));
        selects.forAll(add("all-2"));
        selects.forKind("k", add("kind-2"));
      });

      assert.deepEqual(
        values(new SelectEngine({ kind: "k", identifier: "i" })),
        ["all-1", "all-2", "kind-1", "kind-2", "identifier-1", "identifier-2"]
      );
    });

    test("load and change compose in tier order too", async function (assert) {
      const trace = [];
      const wrap = (label) => (spec) =>
        spec.load((load) => (filter, opts) => {
          trace.push(label);
          return load(filter, opts);
        });
      const middleware = (label) => (spec) =>
        spec.change((next) => {
          trace.push(label);
          next();
        });
      customize((selects) => {
        selects.forIdentifier("i", wrap("load-identifier"));
        selects.forKind("k", wrap("load-kind"));
        selects.forAll(wrap("load-all"));
        selects.forIdentifier("i", middleware("change-identifier"));
        selects.forKind("k", middleware("change-kind"));
        selects.forAll(middleware("change-all"));
      });
      const engine = new SelectEngine({
        kind: "k",
        identifier: "i",
        load: () => {
          trace.push("load-base");
          return ITEMS;
        },
        getValue: () => null,
        onChange: () => trace.push("emit"),
      });

      await engine.loadItems(engine.loadContext);
      assert.deepEqual(
        trace,
        ["load-identifier", "load-kind", "load-all", "load-base"],
        "each load step wraps the one before it, so the most specific runs first"
      );

      trace.length = 0;
      engine.select(ITEMS[1]);
      assert.deepEqual(
        trace,
        ["change-all", "change-kind", "change-identifier", "emit"],
        "the most general middleware is the outermost"
      );
    });

    test("a setup runs once per matching select, at construction", function (assert) {
      let setups = 0;
      customize((selects) =>
        selects.forKind("k", (spec) => {
          setups++;
          spec.content((items) => items);
        })
      );

      const engine = new SelectEngine({ kind: "k" });
      assert.strictEqual(setups, 1, "construction runs the setup");

      engine.buildItems(ITEMS);
      engine.setFilter("a");
      engine.buildItems(ITEMS);
      assert.strictEqual(setups, 1, "building the list never runs it again");

      create({ kind: "k" });
      assert.strictEqual(setups, 2, "another select runs its own setup");

      create({ kind: "other" });
      create({ identifier: "k" });
      create({});
      assert.strictEqual(setups, 2, "non-matching selects never run it");
    });

    test("each select keeps its own setup state", function (assert) {
      customize((selects) =>
        selects.forAll((spec) => {
          let builds = 0;
          spec.content((items) => [
            ...items,
            { id: `build-${++builds}`, name: "Build" },
          ]);
        })
      );
      const first = new SelectEngine({});
      const second = new SelectEngine({});

      assert.deepEqual(values(first), ["build-1"]);
      assert.deepEqual(values(first), ["build-2"], "state survives rebuilds");
      assert.deepEqual(
        values(second),
        ["build-1"],
        "another select starts from its own state"
      );
    });

    test("setup receives only the names", function (assert) {
      const seen = [];
      customize((selects) => {
        selects.forAll((spec, names) => seen.push(names));
        selects.forKind("k", (spec, names) => seen.push(names));
      });

      create({
        kind: "k",
        identifier: "i",
        getKindContext: () => ({ scope: "recipe" }),
        getInstanceContext: () => ({ topicId: 7 }),
      });
      create({});

      assert.strictEqual(seen.length, 3, "two setups, then one");
      for (const names of seen) {
        assert.deepEqual(
          Object.keys(names).sort(),
          ["identifier", "kind"],
          "no control or context data at setup"
        );
      }
      assert.strictEqual(seen[0].kind, "k");
      assert.strictEqual(seen[0].identifier, "i");
      assert.strictEqual(seen[2].kind, undefined, "absent names are undefined");
      assert.strictEqual(seen[2].identifier, undefined);
    });

    test("forKind and forIdentifier require a non-empty string", function (assert) {
      let attempt;
      customize((selects) => attempt(selects));

      for (const [label, register] of [
        ["an empty kind", (selects) => selects.forKind("", () => {})],
        ["a missing kind", (selects) => selects.forKind(undefined, () => {})],
        [
          "a numeric identifier",
          (selects) => selects.forIdentifier(7, () => {}),
        ],
        [
          "an empty identifier",
          (selects) => selects.forIdentifier("", () => {}),
        ],
      ]) {
        attempt = register;
        assert.throws(
          () => new SelectEngine({}),
          /non-empty string/,
          `${label} throws`
        );
      }
    });
  });

  module("setup rules", function () {
    test("registry methods return nothing and the registry is sealed once applied", function (assert) {
      let stored;
      const returned = [];
      customize((selects) => {
        stored = selects;
        returned.push(
          selects.forAll(() => {}),
          selects.forKind("k", () => {}),
          selects.forIdentifier("i", () => {})
        );
      });

      create({});

      assert.deepEqual(returned, [undefined, undefined, undefined]);
      assert.throws(
        () => stored.forAll(add("late")),
        /sealed/,
        "a stored registry throws"
      );
      assert.deepEqual(
        values(new SelectEngine({})),
        [],
        "and its late setup never applies"
      );
    });

    test("a stored spec is sealed after setup", function (assert) {
      let stored;
      customize((selects) =>
        selects.forAll((spec) => {
          stored = spec;
        })
      );

      const engine = new SelectEngine({});
      const spec = stored;

      for (const method of ["content", "row", "load", "change"]) {
        assert.throws(
          () => spec[method](() => {}),
          /sealed/,
          `a late ${method} call throws`
        );
      }
      assert.deepEqual(values(engine), [], "nothing was added late");
    });

    test("an unknown spec member throws", function (assert) {
      customize((selects) => selects.forAll((spec) => spec.contnet((i) => i)));

      assert.throws(
        () => new SelectEngine({}),
        (error) =>
          /unknown/i.test(error.message) && /contnet/.test(error.message),
        "the message names the unknown member"
      );
    });

    test("a throwing setup is reported, skipped as a whole, and its spec is sealed", function (assert) {
      let stored;
      customize((selects) => {
        selects.forAll((spec) => {
          stored = spec;
          add("partial")(spec);
          throw new Error("setup boom");
        });
        selects.forAll(add("healthy"));
      });

      assert.throws(
        () => new SelectEngine({}),
        /setup boom/,
        "tests rethrow the setup's error"
      );
      assert.true(
        this.reported.some(
          (detail) =>
            detail.messageKey === "broken_transformer_alert" &&
            detail.error?.message === "setup boom"
        ),
        "the error is reported"
      );
      assert.throws(
        () => stored.content((i) => i),
        /sealed/,
        "the spec is sealed although setup threw"
      );

      disableThrowingApplyExceptionOnTests();
      assert.deepEqual(
        values(new SelectEngine({})),
        ["healthy"],
        "the failed setup adds nothing, and the others still apply"
      );
    });

    test("an async setup throws", function (assert) {
      customize((selects) => {
        selects.forAll(async (spec) => {
          add("async")(spec);
        });
        selects.forAll(add("healthy"));
      });

      assert.throws(
        () => new SelectEngine({}),
        /setup must be synchronous/,
        "a returned promise throws"
      );

      disableThrowingApplyExceptionOnTests();
      assert.deepEqual(
        values(new SelectEngine({})),
        ["healthy"],
        "it is skipped like any failed setup"
      );
    });

    test("a registry whose application throws is still sealed", function (assert) {
      let stored;
      customize((selects) => {
        stored = selects;
        throw new Error("registration failed");
      });

      assert.throws(
        () => new SelectEngine({}),
        /registration failed/,
        "the registration error reaches tests"
      );
      assert.throws(
        () => stored.forAll(() => {}),
        /sealed/,
        "the registry closes even when application throws"
      );
    });

    test("setups run before construction-time source validation", function (assert) {
      const order = [];
      customize((selects) => selects.forAll(() => order.push("setup")));

      create({
        load: () => [],
        items: () => {
          order.push("items");
          return [];
        },
      });

      assert.deepEqual(
        order,
        ["setup", "items"],
        "the items thunk is first read after setup"
      );
    });
  });

  module("isolation and fallbacks", function () {
    test("a throwing content step is reported, rethrown in tests, and otherwise keeps the previous list", function (assert) {
      customize((selects) => {
        selects.forAll(add("first"));
        selects.forAll((spec) =>
          spec.content(() => {
            throw new Error("content boom");
          })
        );
        selects.forAll(add("last"));
      });
      const engine = new SelectEngine({});

      assert.throws(() => engine.buildItems([]), /content boom/);
      assert.true(
        this.reported.some(
          (detail) =>
            detail.messageKey === "broken_transformer_alert" &&
            detail.error?.message === "content boom"
        ),
        "the error is reported"
      );

      disableThrowingApplyExceptionOnTests();
      assert.deepEqual(
        values(engine),
        ["first", "last"],
        "the failing step is skipped and the others still run"
      );
    });

    test("a content step that returns no array keeps the previous list", function (assert) {
      customize((selects) => {
        selects.forAll((spec) => spec.content(() => undefined));
        selects.forAll(add("after"));
      });
      const engine = new SelectEngine({});

      assert.throws(
        () => engine.buildItems(ITEMS),
        /must return an array/i,
        "development flags the mistake"
      );

      disableThrowingApplyExceptionOnTests();
      assert.deepEqual(
        values(engine, ITEMS),
        [1, 2, "after"],
        "the list is unchanged by that step"
      );
    });

    test("a throwing load step keeps the previous loader", async function (assert) {
      const calls = [];
      customize((selects) => {
        selects.forAll((spec) =>
          spec.load(() => {
            throw new Error("load boom");
          })
        );
        selects.forAll((spec) =>
          spec.load((load) => (filter, opts) => {
            calls.push("wrapped");
            return load(filter, opts);
          })
        );
      });
      const load = () => {
        calls.push("base");
        return ITEMS;
      };

      const failing = new SelectEngine({ load });
      await assert.rejects(
        failing.loadItems(failing.loadContext),
        /load boom/,
        "tests rethrow"
      );

      disableThrowingApplyExceptionOnTests();
      calls.length = 0;
      const engine = new SelectEngine({ load });
      await engine.loadItems(engine.loadContext);
      assert.deepEqual(
        calls,
        ["wrapped", "base"],
        "the failing step is skipped and the next one wraps the original loader"
      );
    });

    test("a throwing change middleware falls through to the emit", function (assert) {
      customize((selects) =>
        selects.forAll((spec) =>
          spec.change(() => {
            throw new Error("middleware boom");
          })
        )
      );

      const failing = controlled();
      assert.throws(
        () => failing.engine.select(ITEMS[1]),
        /middleware boom/,
        "tests rethrow"
      );

      disableThrowingApplyExceptionOnTests();
      const { engine, changes } = controlled();
      engine.select(ITEMS[1]);
      assert.deepEqual(changes, [2], "the change is emitted once");
      assert.true(
        this.reported.some(
          (detail) => detail.error?.message === "middleware boom"
        ),
        "the error is reported"
      );
    });

    test("a middleware that throws after next() does not emit twice", function (assert) {
      disableThrowingApplyExceptionOnTests();
      let ran = 0;
      customize((selects) =>
        selects.forAll((spec) =>
          spec.change((next) => {
            ran++;
            next();
            throw new Error("after next");
          })
        )
      );

      const { engine, changes } = controlled();
      engine.select(ITEMS[1]);

      assert.strictEqual(ran, 1, "the middleware ran");
      assert.deepEqual(changes, [2], "one emit");
    });

    test("a rejected async middleware falls through once", async function (assert) {
      disableThrowingApplyExceptionOnTests();
      customize((selects) =>
        selects.forAll((spec) =>
          spec.change(async () => {
            await Promise.resolve();
            throw new Error("async boom");
          })
        )
      );

      const { engine, changes } = controlled();
      engine.select(ITEMS[1]);
      await settled();

      assert.deepEqual(changes, [2], "the change is emitted once");
      assert.true(
        this.reported.some((detail) => detail.error?.message === "async boom"),
        "the rejection is reported"
      );
    });

    test("a second next() does not emit twice", function (assert) {
      let ran = 0;
      customize((selects) =>
        selects.forAll((spec) =>
          spec.change((next) => {
            ran++;
            next();
            next();
          })
        )
      );

      const { engine, changes } = controlled();
      engine.select(ITEMS[1]);

      assert.strictEqual(ran, 1, "the middleware ran");
      assert.deepEqual(changes, [2], "one emit");
    });

    test("a consumer onChange error propagates past middleware", function (assert) {
      disableThrowingApplyExceptionOnTests();
      const order = [];
      customize((selects) =>
        selects.forAll((spec) =>
          spec.change((next) => {
            order.push("before");
            next();
            order.push("after");
          })
        )
      );
      const engine = new SelectEngine({
        items: ITEMS,
        getValue: () => null,
        onChange: () => {
          throw new Error("consumer boom");
        },
      });

      assert.throws(
        () => engine.select(ITEMS[1]),
        /consumer boom/,
        "the consumer's error reaches the caller"
      );
      assert.deepEqual(order, ["before"], "the middleware did not continue");
      assert.false(
        this.reported.some(
          (detail) => detail.error?.message === "consumer boom"
        ),
        "it is not reported as a broken customization"
      );
    });

    test("a throwing row step keeps what it set, and later steps still run", function (assert) {
      disableThrowingApplyExceptionOnTests();
      customize((selects) => {
        selects.forAll((spec) =>
          spec.row((row) => {
            row.classes.push("partial");
            throw new Error("row failed");
          })
        );
        selects.forAll((spec) =>
          spec.row((row) => row.classes.push("healthy"))
        );
      });
      const engine = new SelectEngine({});
      const [descriptor] = engine.buildItems([{ id: 1, name: "Apple" }]);

      assert.deepEqual(
        engine.rowPresentation(descriptor).classes,
        ["partial", "healthy"],
        "partial mutations survive and the following step runs"
      );
      assert.deepEqual(
        engine.rowPresentation(descriptor).classes,
        ["partial", "healthy"],
        "a later evaluation starts fresh"
      );
      assert.strictEqual(this.reported.length, 2, "each failure is reported");
      assert.true(
        this.reported.every(
          (detail) =>
            detail.messageKey === "broken_transformer_alert" &&
            detail.error.message === "row failed"
        ),
        "as a broken customization"
      );
    });

    test("a load step that returns no function keeps the previous loader", async function (assert) {
      disableThrowingApplyExceptionOnTests();
      const calls = [];
      customize((selects) =>
        selects.forAll((spec) => {
          spec.load((load) => (filter, opts) => {
            calls.push("before");
            return load(filter, opts);
          });
          spec.load(() => null);
          spec.load((load) => (filter, opts) => {
            calls.push("after");
            return load(filter, opts);
          });
        })
      );
      const engine = new SelectEngine({
        load: () => {
          calls.push("base");
          return [];
        },
      });

      await engine.loadItems(engine.loadContext);

      assert.deepEqual(
        calls,
        ["after", "before", "base"],
        "both valid steps wrap the original loader"
      );
      assert.strictEqual(
        this.reported.length,
        1,
        "the invalid step is reported"
      );
    });

    test("a rejection after an awaited next() replays nothing downstream", async function (assert) {
      disableThrowingApplyExceptionOnTests();
      const calls = [];
      customize((selects) =>
        selects.forAll((spec) => {
          spec.change(async (next) => {
            await next();
            throw new Error("after await");
          });
          spec.change((next) => {
            calls.push("inner");
            next();
          });
        })
      );
      const { engine, changes } = controlled();

      engine.select(ITEMS[1]);
      await settled();

      assert.deepEqual(calls, ["inner"], "the inner middleware ran once");
      assert.deepEqual(changes, [2], "the change was emitted once");
      assert.strictEqual(this.reported.length, 1, "the rejection is reported");
    });
  });
});

module("Unit | ui-kit | select-customizations | options", function (hooks) {
  setupTest(hooks);

  function noneRow(engine) {
    return engine.buildItems(ITEMS).find((row) => row.flags.__none)?.item.name;
  }

  test("noneLabel reaches a headless engine", function (assert) {
    customize((selects) =>
      selects.forAll((spec) => spec.options(() => ({ noneLabel: "Nothing" })))
    );

    assert.strictEqual(
      noneRow(new SelectEngine({ items: ITEMS, noneLabel: "None" })),
      "Nothing",
      "it renames the static none label"
    );
    assert.strictEqual(
      noneRow(new SelectEngine({ items: ITEMS, getNoneLabel: () => "None" })),
      "Nothing",
      "it wins over the live reader"
    );
    assert.strictEqual(
      noneRow(new SelectEngine({ items: ITEMS })),
      "Nothing",
      "it adds a none row where there was none"
    );
    assert.strictEqual(
      noneRow(new SelectEngine({ items: ITEMS, multiple: true })),
      undefined,
      "a multi-select still has no none row"
    );
  });

  test("a throwing options callback is reported and its partial skipped", function (assert) {
    customize((selects) => {
      selects.forAll((spec) =>
        spec.options(() => {
          throw new Error("options boom");
        })
      );
      selects.forAll((spec) => spec.options(() => ({ noneLabel: "After" })));
    });
    const engine = new SelectEngine({ items: ITEMS, noneLabel: "None" });

    assert.throws(() => engine.buildItems(ITEMS), /options boom/);

    disableThrowingApplyExceptionOnTests();
    assert.strictEqual(
      noneRow(new SelectEngine({ items: ITEMS, noneLabel: "None" })),
      "After",
      "later callbacks still apply"
    );
  });

  test("options takes only a function", function (assert) {
    customize((selects) => selects.forAll((spec) => spec.options("label")));

    assert.throws(() => new SelectEngine({}), /must be a function/);
  });

  test("each callback gets a frozen snapshot, and an earlier lock survives a later false", function (assert) {
    const snapshots = [];
    const caret = { open: "plus", closed: "minus" };
    customize((selects) => {
      selects.forIdentifier("fruit", (spec) =>
        spec.options((current) => {
          snapshots.push(current);
          return { disabled: false, ariaLabel: "Identifier" };
        })
      );
      selects.forAll((spec) => {
        spec.options((current) => {
          snapshots.push(current);
          return { disabled: true, ariaLabel: "First", caretIcon: caret };
        });
        spec.options((current) => {
          snapshots.push(current);
          return { disabled: false, ariaLabel: "Second" };
        });
      });
    });
    const engine = new SelectEngine({
      identifier: "fruit",
      getOptions: () => ({ ariaLabel: "Base" }),
    });

    assert.true(engine.resolvedOptions.disabled, "the first lock stays");
    assert.strictEqual(
      engine.resolvedOptions.ariaLabel,
      "Identifier",
      "the most specific tier wins"
    );
    assert.deepEqual(
      snapshots.map((snapshot) => snapshot.ariaLabel),
      ["Base", "First", "Second"],
      "earlier snapshots keep their values"
    );
    assert.true(snapshots.every(Object.isFrozen), "every snapshot is frozen");
    assert.true(
      Object.isFrozen(engine.resolvedOptions.caretIcon),
      "nested caret state is frozen too"
    );
    assert.false(Object.isFrozen(caret), "the callback's own object is not");
  });

  test("a headless noneLabel follows the live reader until a customization overrides it", function (assert) {
    const state = new (class {
      @tracked label;
      @tracked multiple = false;
      @tracked override;
    })();
    customize((selects) =>
      selects.forAll((spec) =>
        spec.options(() =>
          state.override === undefined ? {} : { noneLabel: state.override }
        )
      )
    );
    const engine = new SelectEngine({
      noneLabel: "Static",
      getNoneLabel: () => state.label,
      getMultiple: () => state.multiple,
    });
    const noneLabel = () =>
      engine.buildItems([]).find((row) => row.flags.__none)?.item.name;

    assert.strictEqual(noneLabel(), "Static", "the static label is the base");
    state.label = "Live";
    assert.strictEqual(noneLabel(), "Live", "the live reader takes over");
    state.override = "Override";
    assert.strictEqual(noneLabel(), "Override", "the customization wins");
    state.multiple = true;
    assert.strictEqual(
      noneLabel(),
      undefined,
      "a multi-select has no none row"
    );
    state.multiple = false;
    state.override = "";
    assert.strictEqual(
      noneLabel(),
      undefined,
      "an empty label removes the row"
    );
    state.override = undefined;
    assert.strictEqual(
      noneLabel(),
      "Live",
      "dropping the override restores it"
    );
  });

  test("resolving options never reads items or the lock", function (assert) {
    let itemReads = 0;
    customize((selects) =>
      selects.forAll((spec) =>
        spec.options((current, context) => ({
          disabled: context.control.value === 2 && !context.control.pending,
        }))
      )
    );
    const engine = new SelectEngine({
      items: () => {
        itemReads++;
        return [];
      },
      getValue: () => 2,
      valueItems: { id: 2, name: "Two" },
      getLocked: () => {
        throw new Error("must not read locked");
      },
    });
    const before = itemReads;

    assert.true(engine.resolvedOptions.disabled, "the value drives the lock");
    assert.strictEqual(itemReads, before, "no item reads");
  });
});

module(
  "Unit | ui-kit | select-customizations | recipe options",
  function (hooks) {
    setupTest(hooks);

    test("declared keys stay fixed while nullish base values stay live", function (assert) {
      const state = trackedObject({
        options: { prefix: undefined, suffix: null },
      });
      const warn = sinon.stub(console, "warn");
      const seen = [];
      customize((selects) =>
        selects.forKind("recipe", (spec) =>
          spec.options((current) => {
            seen.push(current);
            return { prefix: current.prefix ?? "fallback", added: "ignored" };
          })
        )
      );

      try {
        const engine = new SelectEngine({
          kind: "recipe",
          getKindOptions: () => state.options,
        });
        assert.strictEqual(
          engine.resolvedOptions.prefix,
          "fallback",
          "an undefined key can be overridden"
        );
        assert.true(
          Object.hasOwn(seen[0], "prefix"),
          "undefined stays declared"
        );
        assert.true(Object.hasOwn(seen[0], "suffix"), "null stays declared");
        assert.strictEqual(seen[0].suffix, undefined, "null has no base value");

        state.options = { prefix: "live", added: "new" };
        assert.strictEqual(
          engine.resolvedOptions.prefix,
          "live",
          "new values are live"
        );
        assert.false(
          Object.hasOwn(engine.resolvedOptions, "added"),
          "a later key does not extend the declared set"
        );
        assert.true(
          Object.hasOwn(seen[1], "suffix"),
          "a removed key stays declared"
        );
        assert.true(warn.calledWithMatch('"added"'), "an undeclared key warns");
        assert.false(
          warn.calledWithMatch('"prefix"'),
          "a declared key without a value does not"
        );
      } finally {
        warn.restore();
      }
    });

    test("a deferred emit keeps its snapshot after live values change", async function (assert) {
      const state = trackedObject({ prefix: "before" });
      let resume, context, emitted;
      customize((selects) =>
        selects.forKind("recipe", (spec) =>
          spec.change((next, ctx) => {
            resume = next;
            context = ctx;
          })
        )
      );
      const engine = new SelectEngine({
        kind: "recipe",
        getKindOptions: () => ({ prefix: state.prefix }),
        onChange: (_value, _item, change) => (emitted = change),
      });

      engine.select({ id: 1 });
      state.prefix = "after";
      assert.strictEqual(
        engine.resolvedOptions.prefix,
        "after",
        "the live options moved on"
      );

      await resume();
      assert.strictEqual(
        emitted.options,
        context.options,
        "the middleware and the emit share the snapshot"
      );
      assert.strictEqual(
        emitted.options.prefix,
        "before",
        "the deferred emit keeps the original values"
      );
      assert.true(Object.isFrozen(emitted.options), "the snapshot is frozen");
    });
  }
);
