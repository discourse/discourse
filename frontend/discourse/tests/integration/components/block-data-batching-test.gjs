import Component from "@glimmer/component";
import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block, defineBlockDataSource } from "discourse/blocks";
import BlockOutlet from "discourse/blocks/block-outlet";
import { resetBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | block data batching", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    resetBlockData();
  });

  test("blocks sharing a batched source resolve through one combined request", async function (assert) {
    let resolveBatch;
    const requests = [];
    const batchPromise = new Promise((resolve) => (resolveBatch = resolve));

    const source = defineBlockDataSource({
      name: "batching-test-source",
      batch: {
        request(descriptors) {
          requests.push(descriptors);
          return { descriptors };
        },
        resolve: () => batchPromise,
        extract: (response, descriptor) => `${response.stamp}:${descriptor.id}`,
      },
    });

    @block("batching-list-block", {
      args: { label: { type: "string" } },
      data: {
        request: (args) => ({ kind: "list", id: args.label }),
        source,
        skeleton: () => ({ variant: "rect", count: 1 }),
      },
    })
    class BatchingListBlock extends Component {
      <template>
        <@Data>
          <:content as |value|>
            <div class="list-content">{{value}}</div>
          </:content>
        </@Data>
      </template>
    }

    @block("batching-card-block", {
      args: { label: { type: "string" } },
      data: {
        request: (args) => ({ kind: "card", id: args.label }),
        source,
        skeleton: () => ({ variant: "rect", count: 1 }),
      },
    })
    class BatchingCardBlock extends Component {
      <template>
        <@Data>
          <:content as |value|>
            <div class="card-content">{{value}}</div>
          </:content>
        </@Data>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: BatchingListBlock, args: { label: "a" } },
        { block: BatchingListBlock, args: { label: "b" } },
        { block: BatchingCardBlock, args: { label: "c" } },
      ])
    );

    // A pending TrackedAsyncData keeps the run loop busy, so `settled()` would
    // block while the batch is in flight. Wait for the rendered DOM instead.
    const renderPromise = render(
      <template><BlockOutlet @name="hero-blocks" /></template>
    );

    await waitFor(".d-skeleton");
    assert
      .dom(".d-skeleton")
      .exists(
        { count: 3 },
        "every block shows its skeleton while the batch is pending"
      );

    resolveBatch({ stamp: "batched" });
    await renderPromise;
    await settled();

    assert.strictEqual(requests.length, 1, "one combined request was built");
    assert.deepEqual(
      requests[0],
      [
        { kind: "list", id: "a" },
        { kind: "list", id: "b" },
        { kind: "card", id: "c" },
      ],
      "the combined request carried every block's descriptor"
    );

    const listContents = [...document.querySelectorAll(".list-content")].map(
      (el) => el.textContent.trim()
    );
    assert.deepEqual(
      listContents,
      ["batched:a", "batched:b"],
      "each list block rendered its own slice"
    );
    assert
      .dom(".card-content")
      .hasText("batched:c", "the other block kind rendered its own slice");
  });

  test("identical descriptors from different block kinds share one slice", async function (assert) {
    const requests = [];

    const source = defineBlockDataSource({
      name: "batching-dedup-source",
      batch: {
        request(descriptors) {
          requests.push(descriptors);
          return { descriptors };
        },
        resolve: () => Promise.resolve({}),
        extract: (response, descriptor) => `value:${descriptor.id}`,
      },
    });

    @block("dedup-first-block", {
      data: {
        request: () => ({ id: "shared" }),
        source,
      },
    })
    class DedupFirstBlock extends Component {
      <template>
        <@Data>
          <:content as |value|>
            <div class="first-content">{{value}}</div>
          </:content>
        </@Data>
      </template>
    }

    @block("dedup-second-block", {
      data: {
        request: () => ({ id: "shared" }),
        source,
      },
    })
    class DedupSecondBlock extends Component {
      <template>
        <@Data>
          <:content as |value|>
            <div class="second-content">{{value}}</div>
          </:content>
        </@Data>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: DedupFirstBlock },
        { block: DedupSecondBlock },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.deepEqual(
      requests,
      [[{ id: "shared" }]],
      "the named source deduped the identical descriptor into one fetch"
    );
    assert.dom(".first-content").hasText("value:shared");
    assert.dom(".second-content").hasText("value:shared");
  });
});
