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
          measure: () => {
            log.push("read");
            return { i };
          },
          decide: (_avail, data) => `tier-${data.i}`,
          apply: { callback: (tier) => log.push(`write:${tier}`) },
        })
      )
    );
    await settled();

    assert.strictEqual(
      log.filter((e) => e === "read").length,
      3,
      "each target is measured once"
    );
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
        measure: () => ({}),
        decide: () => "same",
        apply: { callback: (tier) => writes.push(tier) },
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
        measure: () => ({}),
        decide: () => tier,
        apply: { attribute: "data-fit" },
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
        measure: () => ({}),
        decide: () => "x",
        apply: { callback: () => writes.push("x") },
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
