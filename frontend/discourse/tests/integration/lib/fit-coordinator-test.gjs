import { run } from "@ember/runloop";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  refreshFit,
  registerFit,
  resetFitCoordinator,
  unregisterFit,
} from "discourse/lib/fit-coordinator";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Library | fit-coordinator", function (hooks) {
  setupRenderingTest(hooks);

  test("K targets measure in one read-all-then-write-all pass", async function (assert) {
    await render(
      <template>
        <div class="fit-t"></div>
        <div class="fit-t"></div>
        <div class="fit-t"></div>
      </template>
    );

    const els = [...document.querySelectorAll(".fit-t")];
    const log = [];

    // Register all targets inside one runloop so their coalesced measure runs as
    // a single afterRender pass (the batching under test).
    run(() =>
      els.forEach((el, i) =>
        registerFit({
          key: el,
          observedEl: el,
          compute: () => {
            log.push("read");
            return `tier-${i}`;
          },
          onChange: (tier) => log.push(`write:${tier}`),
        })
      )
    );
    await settled();

    // Reads come in whole read-all batches of three, one per measure trigger.
    // Observing an element makes the ResizeObserver deliver an initial
    // notification, so besides the registration-triggered pass a second,
    // identical pass can run — hence a multiple of three rather than exactly
    // three. That second pass re-reads but writes nothing (the decisions are
    // unchanged and writes are diffed), which is what keeps the write count and
    // the no-interleaving guarantee below exact.
    const reads = log.filter((e) => e === "read").length;
    assert.strictEqual(reads % 3, 0, "targets are measured in whole batches");
    assert.true(reads >= 3, "every target is measured at least once");
    assert.strictEqual(
      log.filter((e) => e.startsWith("write")).length,
      3,
      "each changed target is applied once"
    );
    const firstWrite = log.findIndex((e) => e.startsWith("write"));
    assert.strictEqual(
      firstWrite,
      3,
      "all three reads precede the first write — no interleaving"
    );
  });

  test("an unchanged decision is not re-applied (diffed writes)", async function (assert) {
    await render(
      <template>
        <div class="fit-t"></div>
      </template>
    );
    const el = document.querySelector(".fit-t");
    const writes = [];

    run(() =>
      registerFit({
        key: el,
        observedEl: el,
        compute: () => "same",
        onChange: (tier) => writes.push(tier),
      })
    );
    await settled();
    assert.deepEqual(writes, ["same"], "the first decision applies");

    run(() => refreshFit(el));
    await settled();
    assert.deepEqual(
      writes,
      ["same"],
      "re-measuring with an unchanged decision does not re-apply"
    );
  });

  test("attribute strategy writes and clears the tier", async function (assert) {
    await render(
      <template>
        <div class="fit-t"></div>
      </template>
    );
    const el = document.querySelector(".fit-t");
    let tier = "a";

    run(() =>
      registerFit({
        key: el,
        observedEl: el,
        compute: () => tier,
        attribute: "data-fit",
      })
    );
    await settled();
    assert.dom(el).hasAttribute("data-fit", "a");

    tier = "b";
    run(() => refreshFit(el));
    await settled();
    assert
      .dom(el)
      .hasAttribute("data-fit", "b", "a changed decision updates it");

    unregisterFit(el);
    assert
      .dom(el)
      .doesNotHaveAttribute("data-fit", "unregister clears the attribute");
  });

  test("registering with both or neither write strategy throws", async function (assert) {
    await render(
      <template>
        <div class="fit-t"></div>
      </template>
    );
    const el = document.querySelector(".fit-t");

    assert.throws(
      () => registerFit({ key: el, observedEl: el, compute: () => "x" }),
      /exactly one/,
      "neither strategy throws"
    );
    assert.throws(
      () =>
        registerFit({
          key: el,
          observedEl: el,
          compute: () => "x",
          attribute: "data-fit",
          onChange: () => {},
        }),
      /exactly one/,
      "both strategies throw"
    );
  });

  test("resetFitCoordinator drops all registrations", async function (assert) {
    await render(
      <template>
        <div class="fit-t"></div>
      </template>
    );
    const el = document.querySelector(".fit-t");
    const writes = [];

    run(() =>
      registerFit({
        key: el,
        observedEl: el,
        compute: () => "x",
        onChange: () => writes.push("x"),
      })
    );
    await settled();
    assert.strictEqual(writes.length, 1);

    resetFitCoordinator();
    run(() => refreshFit(el));
    await settled();
    assert.strictEqual(writes.length, 1, "no measure runs after a reset");
  });
});
