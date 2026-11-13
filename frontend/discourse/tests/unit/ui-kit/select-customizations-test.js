import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { trackedObject } from "@ember/reactive/collections";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { disableThrowingApplyExceptionOnTests } from "discourse/lib/transformer";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import { optionsFromLegacyRows } from "discourse/ui-kit/select/-internals/engine/legacy-rows";
import SelectArgsView from "discourse/ui-kit/select/-internals/engine/select-args";
import { isSelectOption } from "discourse/ui-kit/select/-internals/engine/select-option";
import SelectEngine, {
  selectOption,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

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
  return engine.buildRows(items).map((row) => row.value);
}

/** A single select whose emitted changes are recorded. */
function controlled(opts = {}) {
  const changes = [];
  const engine = new SelectEngine({
    options: ITEMS,
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

      await engine.loadOptions(engine.loadContext);
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

      engine.buildRows(ITEMS);
      engine.setFilter("a");
      engine.buildRows(ITEMS);
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

      for (const method of ["content", "optionAttributes", "load", "change"]) {
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
        options: () => {
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

      assert.throws(() => engine.buildRows([]), /content boom/);
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
        () => engine.buildRows(ITEMS),
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
        failing.loadOptions(failing.loadContext),
        /load boom/,
        "tests rethrow"
      );

      disableThrowingApplyExceptionOnTests();
      calls.length = 0;
      const engine = new SelectEngine({ load });
      await engine.loadOptions(engine.loadContext);
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
        options: ITEMS,
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

    test("a throwing attributes step keeps what it set, and later steps still run", function (assert) {
      disableThrowingApplyExceptionOnTests();
      customize((selects) => {
        selects.forAll((spec) =>
          spec.optionAttributes((attributes) => {
            attributes.classes.push("partial");
            throw new Error("attributes failed");
          })
        );
        selects.forAll((spec) =>
          spec.optionAttributes((attributes) =>
            attributes.classes.push("healthy")
          )
        );
      });
      const engine = new SelectEngine({});
      const [descriptor] = engine.buildRows([{ id: 1, name: "Apple" }]);

      assert.deepEqual(
        engine.optionAttributes(descriptor).classes,
        ["partial", "healthy"],
        "partial mutations survive and the following step runs"
      );
      assert.deepEqual(
        engine.optionAttributes(descriptor).classes,
        ["partial", "healthy"],
        "a later evaluation starts fresh"
      );
      assert.strictEqual(this.reported.length, 2, "each failure is reported");
      assert.true(
        this.reported.every(
          (detail) =>
            detail.messageKey === "broken_transformer_alert" &&
            detail.error.message === "attributes failed"
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

      await engine.loadOptions(engine.loadContext);

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

  function noneOption(engine) {
    return engine.buildRows(ITEMS).find((row) => row.flags.none)?.record.name;
  }

  test("a customization's noneOption and noneLabel reach a headless engine", function (assert) {
    customize((selects) =>
      selects.forAll((spec) =>
        spec.config(() => ({
          noneOption: true,
          texts: { noneLabel: "Nothing" },
        }))
      )
    );

    assert.strictEqual(
      noneOption(
        new SelectEngine({
          options: ITEMS,
          getArgs: () => ({ noneOption: true }),
          getTexts: () => ({ noneLabel: "None" }),
        })
      ),
      "Nothing",
      "it renames the call site's none row"
    );
    assert.strictEqual(
      noneOption(new SelectEngine({ options: ITEMS })),
      "Nothing",
      "it adds a none row where there was none"
    );
    assert.strictEqual(
      noneOption(new SelectEngine({ options: ITEMS, multiple: true })),
      undefined,
      "a multi-select still has no none row"
    );
  });

  test("a throwing options callback is reported and its partial skipped", function (assert) {
    customize((selects) => {
      selects.forAll((spec) =>
        spec.config(() => {
          throw new Error("options boom");
        })
      );
      selects.forAll((spec) =>
        spec.config(() => ({ texts: { noneLabel: "After" } }))
      );
    });
    const withNoneRow = () =>
      new SelectEngine({
        options: ITEMS,
        getArgs: () => ({ noneOption: true }),
      });

    assert.throws(() => withNoneRow().buildRows(ITEMS), /options boom/);

    disableThrowingApplyExceptionOnTests();
    assert.strictEqual(
      noneOption(withNoneRow()),
      "After",
      "later callbacks still apply"
    );
  });

  test("options takes only a function", function (assert) {
    customize((selects) => selects.forAll((spec) => spec.config("label")));

    assert.throws(() => new SelectEngine({}), /must be a function/);
  });

  test("each callback gets a frozen snapshot, and an earlier lock survives a later false", function (assert) {
    const snapshots = [];
    const caret = { open: "plus", closed: "minus" };
    customize((selects) => {
      selects.forIdentifier("fruit", (spec) =>
        spec.config((current) => {
          snapshots.push(current);
          return { disabled: false, texts: { ariaLabel: "Identifier" } };
        })
      );
      selects.forAll((spec) => {
        spec.config((current) => {
          snapshots.push(current);
          return {
            disabled: true,
            texts: { ariaLabel: "First" },
            caretIcon: caret,
          };
        });
        spec.config((current) => {
          snapshots.push(current);
          return { disabled: false, texts: { ariaLabel: "Second" } };
        });
      });
    });
    const engine = new SelectEngine({
      identifier: "fruit",
      getTexts: () => ({ ariaLabel: "Base" }),
    });

    assert.true(engine.config.disabled, "the first lock stays");
    assert.strictEqual(
      engine.text("ariaLabel"),
      "Identifier",
      "the most specific tier wins"
    );
    assert.deepEqual(
      snapshots.map((snapshot) => snapshot.texts.ariaLabel),
      ["Base", "First", "Second"],
      "earlier snapshots keep their values"
    );
    assert.true(snapshots.every(Object.isFrozen), "every snapshot is frozen");
    assert.true(
      snapshots.every((snapshot) => Object.isFrozen(snapshot.texts)),
      "so are their texts"
    );
    assert.true(
      Object.isFrozen(engine.config.caretIcon),
      "nested caret state is frozen too"
    );
    assert.false(Object.isFrozen(caret), "the callback's own object is not");
  });

  test("a headless none row follows the live texts until a customization overrides them", function (assert) {
    const state = new (class {
      @tracked label;
      @tracked multiple = false;
      @tracked override;
    })();
    customize((selects) =>
      selects.forAll((spec) =>
        spec.config(() =>
          state.override === undefined
            ? {}
            : { texts: { noneLabel: state.override } }
        )
      )
    );
    const engine = new SelectEngine({
      getArgs: () => ({ noneOption: true }),
      getTexts: () => ({ noneLabel: state.label }),
      getMultiple: () => state.multiple,
    });
    const noneLabel = () =>
      engine.buildRows([]).find((row) => row.flags.none)?.record.name;

    assert.strictEqual(
      noneLabel(),
      i18n("d_select.none"),
      "the engine default is the base"
    );
    state.label = "Live";
    assert.strictEqual(noneLabel(), "Live", "the live texts take over");
    state.override = "Override";
    assert.strictEqual(noneLabel(), "Override", "the customization wins");
    state.multiple = true;
    assert.strictEqual(
      noneLabel(),
      undefined,
      "a multi-select has no none row"
    );
    state.multiple = false;
    state.override = undefined;
    assert.strictEqual(
      noneLabel(),
      "Live",
      "dropping the override restores it"
    );
  });

  test("resolving config never reads items or the lock", function (assert) {
    let itemReads = 0;
    customize((selects) =>
      selects.forAll((spec) =>
        spec.config((current, context) => ({
          disabled: context.control.value === 2 && !context.control.pending,
        }))
      )
    );
    const engine = new SelectEngine({
      options: () => {
        itemReads++;
        return [];
      },
      getValue: () => 2,
      valueRecords: { id: 2, name: "Two" },
      getLocked: () => {
        throw new Error("must not read locked");
      },
    });
    const before = itemReads;

    assert.true(engine.config.disabled, "the value drives the lock");
    assert.strictEqual(itemReads, before, "no item reads");
  });
});

module(
  "Unit | ui-kit | select-customizations | recipe config",
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
          spec.config((current) => {
            seen.push(current);
            return { prefix: current.prefix ?? "fallback", added: "ignored" };
          })
        )
      );

      try {
        const engine = new SelectEngine({
          kind: "recipe",
          getKindConfig: () => state.options,
        });
        assert.strictEqual(
          engine.config.prefix,
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
        assert.strictEqual(engine.config.prefix, "live", "new values are live");
        assert.false(
          Object.hasOwn(engine.config, "added"),
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
        getKindConfig: () => ({ prefix: state.prefix }),
        onChange: (_value, _item, change) => (emitted = change),
      });

      engine.select({ id: 1 });
      state.prefix = "after";
      assert.strictEqual(
        engine.config.prefix,
        "after",
        "the live config moved on"
      );

      await resume();
      assert.strictEqual(
        emitted.config,
        context.config,
        "the middleware and the emit share the snapshot"
      );
      assert.strictEqual(
        emitted.config.prefix,
        "before",
        "the deferred emit keeps the original values"
      );
      assert.true(Object.isFrozen(emitted.config), "the snapshot is frozen");
    });
  }
);

/** An engine the legacy bridge reaches, under the kind its callbacks target. */
function bridgeEngine(owner, options = {}) {
  const element = document.createElement("div");
  return new SelectEngine({
    kind: "options-bridge",
    getValue: () => null,
    legacy: {
      owner,
      getElement: () => element,
      isDestroyed: () => false,
    },
    ...options,
  });
}

module(
  "Unit | ui-kit | select-customizations | options and records",
  function (hooks) {
    setupTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

    test("an attributes step gets the option and its record", function (assert) {
      let context;
      customize((selects) =>
        selects.forAll((spec) =>
          spec.optionAttributes((attributes, received) => {
            context = received;
            attributes.title = "Presented";
          })
        )
      );
      const engine = new SelectEngine({});
      const record = { id: 1, name: "Record" };
      const [row] = engine.buildRows([
        selectOption(record, { disabled: true }),
      ]);
      const attributes = engine.optionAttributes(row);
      assert.strictEqual(
        attributes?.title,
        "Presented",
        "the step's attributes are returned"
      );
      assert.strictEqual(
        context?.record,
        record,
        "the context carries the caller's record"
      );
      assert.strictEqual(
        context?.option,
        row.option,
        "the context carries the presented option"
      );
    });

    test("content tiers receive wrapped predecessors and merge settings", function (assert) {
      const record = Object.freeze({ id: 1, name: "Original" });
      const added = Object.freeze({ id: 2, name: "Added" });
      const action = () => {};
      const input = selectOption(record, {
        disabled: true,
        description: "Initial",
        position: "sticky",
        onSelect: action,
      });
      const seen = [];
      customize((selects) => {
        selects.forIdentifier("options", (spec) =>
          spec.content((options) => {
            seen.push(options);
            return options.map((entry) =>
              selectOption(entry).with({ description: null, divider: null })
            );
          })
        );
        selects.forKind("options", (spec) =>
          spec.content((options) => {
            seen.push(options);
            return options.map((entry) =>
              selectOption(entry).with({
                description: "Final",
                divider: "after",
              })
            );
          })
        );
        selects.forAll((spec) =>
          spec.content((options) => {
            seen.push(options);
            return [
              selectOption(options[0]).with({
                disabled: null,
                description: undefined,
                position: null,
                onSelect: null,
              }),
              added,
            ];
          })
        );
      });

      const engine = new SelectEngine({
        kind: "options",
        identifier: "options",
      });
      const rows = engine.buildRows([input]);
      assert.strictEqual(seen.length, 3, "all three tiers ran");
      for (const options of seen) {
        assert.true(
          options.every(isSelectOption),
          "every tier receives only options"
        );
      }
      assert.strictEqual(
        seen[0][0]?.record,
        record,
        "the first step gets the source record"
      );
      assert.strictEqual(
        seen[0][0]?.description,
        "Initial",
        "source settings reach the first step"
      );
      assert.strictEqual(
        seen[1][0]?.description,
        "Initial",
        "undefined preserves a setting"
      );
      assert.strictEqual(
        seen[1][1]?.record,
        added,
        "a returned record is wrapped before the next step"
      );
      const option = rows.find((row) => row.record === record)?.option;
      assert.strictEqual(
        option?.record,
        record,
        "with never copies the record"
      );
      assert.strictEqual(
        seen[2][0]?.description,
        "Final",
        "a later step replaces description"
      );
      assert.strictEqual(
        seen[2][0]?.divider,
        "after",
        "a later step adds a setting"
      );
      assert.strictEqual(
        option?.description,
        undefined,
        "the final step clears description"
      );
      assert.strictEqual(
        option?.divider,
        undefined,
        "the final step clears divider"
      );
      assert.false(option?.disabled, "null clears disabled");
      assert.false(option?.action, "null clears the action");
      assert.strictEqual(option?.position, undefined, "null clears position");
      assert.strictEqual(
        input.description,
        "Initial",
        "the original option is untouched"
      );
      assert.true(input.disabled, "the original settings are untouched");
    });

    test("fields on a record returned by content are data", function (assert) {
      let actions = 0;
      const record = Object.freeze({
        id: 7,
        name: "Data fields",
        disabled: true,
        sticky: true,
        description: "Record data",
        onSelect() {
          actions++;
        },
      });
      customize((selects) =>
        selects.forAll((spec) => spec.content(() => [record]))
      );
      const changes = [];
      const engine = new SelectEngine({
        getValue: () => null,
        onChange: (value, payload) => changes.push([value, payload]),
      });
      const [row] = engine.buildRows([]);

      assert.strictEqual(row.record, record, "the record is not copied");
      assert.deepEqual(
        row.option.settings,
        {},
        "record fields provide no settings"
      );
      assert.false(row.flags.disabled, "disabled is data");
      assert.false(row.flags.sticky, "sticky is data");
      assert.false(row.flags.action, "onSelect is data");
      assert.strictEqual(
        row.option.description,
        undefined,
        "description is data"
      );
      engine.activate(row.option);
      assert.strictEqual(
        actions,
        0,
        "a record method is never called as an action"
      );
      assert.deepEqual(
        changes,
        [[7, record]],
        "activation selects and emits the original record"
      );
    });

    test("a record returned by content has no settings, even when an input matches", function (assert) {
      const first = Object.freeze({ id: 1, name: "Identity" });
      const second = Object.freeze({ id: 2, name: "Key" });
      const copy = Object.freeze({ ...second });
      customize((selects) =>
        selects.forAll((spec) => spec.content(() => [first, copy]))
      );
      const engine = new SelectEngine({});
      const rows = engine.buildRows([
        selectOption(first, {
          description: "Identity setting",
          disabled: true,
        }),
        selectOption(second, {
          description: "Key setting",
          position: "sticky",
        }),
      ]);

      assert.deepEqual(
        rows.map((row) => row.value),
        [1, 2],
        "no inherited position reorders the list"
      );
      assert.strictEqual(
        rows.find((row) => row.value === 1)?.record,
        first,
        "returning a record preserves its identity"
      );
      assert.strictEqual(
        rows.find((row) => row.value === 2)?.record,
        copy,
        "returning a copy preserves that copy"
      );
      for (const row of rows) {
        assert.deepEqual(
          row.option.settings,
          {},
          "a bare result has no settings even when an input matches"
        );
      }
    });

    test("non-array content asserts and retains the previous options", function (assert) {
      const record = { id: 1, name: "Kept" };
      const option = selectOption(record, {
        description: "Kept setting",
        disabled: true,
      });
      let seen;
      customize((selects) =>
        selects.forAll((spec) => {
          spec.content(() => [option]);
          spec.content(() => ({ options: [] }));
          spec.content((options) => {
            seen = options;
            return options;
          });
        })
      );
      const engine = new SelectEngine({});
      assert.throws(
        () => engine.buildRows([]),
        /must return an array/i,
        "a non-array is rejected"
      );
      disableThrowingApplyExceptionOnTests();
      const [row] = engine.buildRows([]);
      assert.strictEqual(
        seen[0],
        option,
        "the following step gets the previous option"
      );
      assert.strictEqual(row.record, record, "the fallback retains the record");
      assert.strictEqual(
        row.option.description,
        "Kept setting",
        "the fallback retains settings"
      );
      assert.true(row.flags.disabled, "the retained option stays disabled");
    });

    test("re-wrapped options keep the source trailing run ahead of an injected group", async function (assert) {
      const a = { id: 1, name: "A one", group: "A" };
      const b = { id: 2, name: "B one", group: "B" };
      const extra = { id: 3, name: "Injected", group: "C" };
      const seen = [];
      customize((selects) =>
        selects.forAll((spec) =>
          spec.content((options) => {
            seen.push(options);
            return [
              ...options.map((entry) =>
                selectOption(entry).with({ description: "Decorated" })
              ),
              selectOption(extra),
            ];
          })
        )
      );
      const engine = new SelectEngine({
        load: () => ({ options: [a, b], hasMore: true }),
        groupBy: "group",
        groupHeader: (key) => `Header ${key}`,
        groupFooter: (key) => `Footer ${key}`,
      });
      const loaded = await engine.loadOptions(engine.loadContext);
      const rows = engine.buildRows(loaded);
      assert.true(
        seen.at(-1).every(isSelectOption),
        "content receives the loaded options"
      );
      assert.deepEqual(
        rows
          .filter((row) => row.flags.groupFooter)
          .map((row) => row.record.label),
        ["Footer A", "Footer C"],
        "B stays held; the injected C run must not become the trailing source run"
      );
      const rebuilt = engine.buildRows(loaded);
      assert.deepEqual(
        rebuilt.map((row) => row.key),
        rows.map((row) => row.key),
        "fresh with wrappers keep boundary keys stable"
      );
      assert.strictEqual(
        rebuilt.find((row) => row.value === 2)?.record,
        b,
        "the held run keeps the source record"
      );
    });

    for (const envelope of [false, true]) {
      test(`load steps wrap ${envelope ? "envelope" : "array"} results between layers`, async function (assert) {
        const base = {
          id: 1,
          name: "Base",
          disabled: true,
          description: "Data",
        };
        const added = {
          id: 2,
          name: "Added",
          sticky: true,
          description: "More data",
        };
        const explicit = selectOption(
          { id: 3, name: "Explicit" },
          { disabled: true, description: "Deliberate" }
        );
        const seen = [];
        const unpack = (result) =>
          Array.isArray(result) ? result : result.options;
        const pack = (options) =>
          envelope
            ? { options, hasMore: false, total: 3, cursor: "last" }
            : options;
        customize((selects) =>
          selects.forAll((spec) => {
            spec.load((load) => async (query, request) => {
              const result = await load(query, request);
              seen.push(unpack(result));
              return pack([
                selectOption(unpack(result)[0]).with({
                  description: "First step",
                }),
                added,
                explicit,
              ]);
            });
            spec.load((load) => async (query, request) => {
              const result = await load(query, request);
              seen.push(unpack(result));
              assert.deepEqual(
                envelope ? [result.cursor, result.total, result.hasMore] : [],
                envelope ? ["last", 3, false] : [],
                "wrapping retains envelope metadata"
              );
              return result;
            });
          })
        );
        const engine = new SelectEngine({ load: () => pack([base]) });
        const options = await engine.loadOptions(engine.loadContext);

        assert.strictEqual(seen.length, 2, "both loader layers ran");
        for (const entries of seen) {
          assert.true(
            entries.every(isSelectOption),
            "the wrapped loader answers with options"
          );
        }
        assert.strictEqual(
          seen[0][0]?.record,
          base,
          "the innermost step receives the original record wrapped"
        );
        assert.deepEqual(
          seen[0][0]?.settings,
          {},
          "base record fields are inert"
        );
        assert.strictEqual(
          seen[1][0]?.description,
          "First step",
          "the next layer keeps explicit settings"
        );
        assert.strictEqual(
          seen[1][1]?.record,
          added,
          "a step's bare record is wrapped for the next layer"
        );
        assert.deepEqual(
          seen[1][1]?.settings,
          {},
          "a step's bare record fields are inert"
        );
        assert.strictEqual(
          seen[1][2]?.description,
          "Deliberate",
          "a returned option keeps its settings"
        );
        assert.strictEqual(
          options[0]?.record,
          base,
          "final wrapping never copies the base record"
        );
        assert.deepEqual(
          options[1]?.settings,
          {},
          "final wrapping does not infer legacy settings"
        );
        assert.true(
          options[2]?.disabled,
          "explicit disabled survives the whole chain"
        );
      });
    }

    for (const multiple of [false, true]) {
      test(`change records have ${multiple ? "multiple" : "single"} arity`, function (assert) {
        const first = { id: 1, name: "First" };
        const second = { id: 2, name: "Second" };
        let held = multiple ? [1] : 1;
        const contexts = [];
        const payloads = [];
        customize((selects) =>
          selects.forAll((spec) =>
            spec.change((next, context) => {
              contexts.push(context);
              next();
            })
          )
        );
        const engine = new SelectEngine({
          multiple,
          options: [selectOption(first, { description: "One" }), second],
          getValue: () => held,
          onChange: (value, records) => {
            held = value;
            payloads.push(records);
          },
        });
        engine.select(second);
        const proposed = contexts[0]?.records;
        const records = multiple ? proposed : [proposed];
        assert.strictEqual(
          records?.[0],
          multiple ? first : second,
          "the first payload entry is the caller's record"
        );
        assert.strictEqual(
          records?.at(-1),
          second,
          "the added record stays a record"
        );
        assert.strictEqual(
          proposed,
          payloads[0],
          "middleware and the consumer share the record payload"
        );
        engine.clear();
        assert.deepEqual(
          contexts[1]?.records,
          multiple ? [] : null,
          "clearing keeps select arity"
        );
        assert.strictEqual(
          contexts.length,
          2,
          "middleware ran for selection and clear"
        );
      });
    }

    test("legacy callbacks and facade content receive records and preserve options by identity", function (assert) {
      const record = Object.freeze({
        id: 1,
        name: "Native",
        disabled: true,
        sticky: true,
        description: "Data",
        onSelect() {},
      });
      const option = selectOption(record, { description: "Explicit" });
      const calls = [];
      withPluginApi((api) => {
        const legacy = api.modifySelectKit("options-bridge");
        for (const method of [
          "prependContent",
          "appendContent",
          "replaceContent",
        ]) {
          legacy[method]((facade, content) => {
            calls.push(method);
            assert.strictEqual(
              content[0],
              record,
              `${method} gets the native record`
            );
            assert.strictEqual(
              facade.content[0],
              record,
              `${method} facade content holds records`
            );
            assert.false(
              content.some(isSelectOption),
              `${method} never sees options`
            );
            return method === "replaceContent" ? content : undefined;
          });
        }
      });
      const engine = bridgeEngine(getOwner(this));
      const [row] = engine.buildRows([option]);
      assert.deepEqual(
        calls,
        ["prependContent", "appendContent", "replaceContent"],
        "every legacy callback ran"
      );
      assert.strictEqual(
        row.option,
        option,
        "an identity result returns the original option"
      );
      assert.strictEqual(
        row.option.description,
        "Explicit",
        "explicit settings survive"
      );
      assert.false(
        row.flags.disabled,
        "native record fields are not translated on an identity return"
      );
      assert.false(row.flags.action, "a native method stays data");
      assert.false(row.flags.sticky, "native sticky stays data");
    });

    test("legacy injected fields translate and actions bind this to the returned row", function (assert) {
      const calls = [];
      const changes = [];
      const action = Object.freeze({
        id: "action",
        name: "Legacy action",
        sticky: true,
        description: "Legacy description",
        onSelect(selectKit, record) {
          calls.push({ receiver: this, selectKit, record });
        },
      });
      const disabled = Object.freeze({
        id: "disabled",
        name: "Disabled",
        disabled: true,
      });
      withPluginApi((api) =>
        api
          .modifySelectKit("options-bridge")
          .appendContent(() => [action, disabled])
      );
      const engine = bridgeEngine(getOwner(this), {
        onChange: (...args) => changes.push(args),
      });
      const rows = engine.buildRows([{ id: "native", name: "Native" }]);
      const row = rows.find((entry) => entry.value === "action");
      assert.strictEqual(
        rows[0].value,
        "action",
        "legacy sticky hoists the action"
      );
      assert.strictEqual(
        row.record,
        action,
        "the bridge never copies an injected record"
      );
      assert.strictEqual(
        row.option.description,
        "Legacy description",
        "legacy description becomes a setting"
      );
      assert.true(
        rows.find((entry) => entry.value === "disabled").flags.disabled,
        "legacy disabled becomes a setting"
      );
      engine.activate(row.option);
      assert.strictEqual(calls.length, 1, "the action ran once");
      assert.strictEqual(
        calls[0]?.receiver,
        action,
        "legacy onSelect receives the row as this"
      );
      assert.strictEqual(
        calls[0]?.record,
        action,
        "legacy onSelect receives the exact returned row"
      );
      assert.strictEqual(
        typeof calls[0]?.selectKit?.set,
        "function",
        "the action gets the legacy facade"
      );
      assert.deepEqual(
        changes,
        [],
        "legacy action activation does not select a value"
      );
    });

    test("legacy unique-key copies inherit settings with legacy fields on top", function (assert) {
      const record = Object.freeze({ id: 0, name: "Native" });
      const copy = Object.freeze({
        ...record,
        disabled: true,
        sticky: true,
        description: "Legacy override",
      });
      withPluginApi((api) =>
        api.modifySelectKit("options-bridge").replaceContent(() => [copy])
      );
      const engine = bridgeEngine(getOwner(this));
      const [row] = engine.buildRows([
        selectOption(record, {
          description: "Native setting",
          position: "end",
          divider: "before",
        }),
      ]);
      assert.strictEqual(row.record, copy, "the copy is the returned record");
      assert.strictEqual(
        row.option.description,
        "Legacy override",
        "legacy description overrides the native setting"
      );
      assert.strictEqual(
        row.option.position,
        "sticky",
        "legacy sticky overrides native end"
      );
      assert.strictEqual(
        row.option.divider,
        "before",
        "a field the legacy copy does not set is inherited"
      );
      assert.true(row.option.disabled, "the legacy copy adds disabled");
      assert.strictEqual(
        record.description,
        undefined,
        "the native record is not mutated"
      );
    });

    test("legacy null and unmatched keys do not inherit native settings", function (assert) {
      const record = Object.freeze({ id: null, name: "Native" });
      const copy = Object.freeze({ ...record, description: "Legacy only" });
      const unmatched = Object.freeze({ id: 9, name: "Unmatched" });
      withPluginApi((api) =>
        api
          .modifySelectKit("options-bridge")
          .replaceContent(() => [copy, unmatched])
      );
      const engine = bridgeEngine(getOwner(this));
      const rows = engine.buildRows([
        selectOption(record, { disabled: true, divider: "after" }),
      ]);
      const returned = rows.find((row) => row.record === copy)?.option;
      assert.strictEqual(
        returned?.description,
        "Legacy only",
        "new legacy fields are translated"
      );
      assert.false(returned?.disabled, "a null key cannot inherit disabled");
      assert.strictEqual(
        returned?.divider,
        undefined,
        "a null key cannot inherit a divider"
      );
      assert.deepEqual(
        rows.find((row) => row.record === unmatched)?.option.settings,
        {},
        "an unmatched key inherits nothing"
      );
    });

    test("legacy ambiguous keys do not inherit either input's settings", function (assert) {
      const first = { id: 1, name: "First" };
      const second = { id: 1, name: "Second" };
      const copy = Object.freeze({ ...first, description: "Legacy" });
      // Exercise ambiguity at the bridge boundary, before source uniqueness removes duplicate keys.
      const [option] = optionsFromLegacyRows(
        [
          selectOption(first, { disabled: true, divider: "before" }),
          selectOption(second, { disabled: true, position: "sticky" }),
        ],
        [copy],
        new SelectArgsView({})
      );
      assert.strictEqual(
        option?.record,
        copy,
        "the returned copy is not copied again"
      );
      assert.deepEqual(
        option?.settings,
        { description: "Legacy" },
        "an ambiguous key translates only the copy's own fields"
      );
    });
  }
);
