import Component from "@glimmer/component";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet from "discourse/blocks/block-outlet";
import {
  blockDataKey,
  resetBlockData,
} from "discourse/lib/blocks/-internals/data-coordinator";
import { withPluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// A fixed descriptor keeps the cache/preload key deterministic across the
// render-time derivation and the test's own key computation.
const DESCRIPTOR = { kind: "test-data" };

module("Integration | Blocks | block data", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    resetBlockData();
  });

  test("shows the skeleton while loading, then the resolved data", async function (assert) {
    let resolveFetch;
    let resolveCalls = 0;
    const fetchPromise = new Promise((resolve) => (resolveFetch = resolve));

    @block("data-skeleton-block", {
      data: {
        request: () => DESCRIPTOR,
        resolve: () => {
          resolveCalls++;
          return fetchPromise;
        },
        skeleton: () => ({ rows: 2 }),
      },
    })
    class DataSkeletonBlock extends Component {
      <template>
        {{#if @data}}
          <div class="resolved-content">{{@data}}</div>
        {{/if}}
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: DataSkeletonBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-skeleton")
      .exists("the skeleton is shown while loading");
    assert.dom(".resolved-content").doesNotExist("no content yet");
    assert.strictEqual(resolveCalls, 1, "the resolver ran once");

    resolveFetch("hello");
    await settled();

    assert.dom(".d-block-skeleton").doesNotExist("the skeleton is gone");
    assert
      .dom(".resolved-content")
      .hasText("hello", "the resolved data is rendered");
  });

  test("uses a preloaded payload immediately without fetching or showing a skeleton", async function (assert) {
    let resolveCalls = 0;
    const key = blockDataKey("data-preload-block", DESCRIPTOR);
    PreloadStore.store(key, "preloaded");

    @block("data-preload-block", {
      data: {
        request: () => DESCRIPTOR,
        resolve: () => {
          resolveCalls++;
          return Promise.resolve("from-network");
        },
      },
    })
    class DataPreloadBlock extends Component {
      <template>
        {{#if @data}}
          <div class="resolved-content">{{@data}}</div>
        {{/if}}
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: DataPreloadBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".resolved-content")
      .hasText("preloaded", "the preloaded payload is rendered");
    assert.dom(".d-block-skeleton").doesNotExist("no skeleton was shown");
    assert.strictEqual(resolveCalls, 0, "the resolver did not run");
    assert.false(PreloadStore.has(key), "the preload key was consumed");
  });

  test("prepareData resolves block data up front so render shows no skeleton", async function (assert) {
    let resolveCalls = 0;

    @block("data-prepare-block", {
      data: {
        request: () => DESCRIPTOR,
        resolve: () => {
          resolveCalls++;
          return Promise.resolve("prepared");
        },
      },
    })
    class DataPrepareBlock extends Component {
      <template>
        {{#if @data}}
          <div class="resolved-content">{{@data}}</div>
        {{/if}}
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: DataPrepareBlock }])
    );

    // Layer 2: resolve the outlet's data the way a route would inside its
    // transition, before anything renders.
    await this.owner.lookup("service:blocks").prepareData("hero-blocks", {});

    assert.strictEqual(resolveCalls, 1, "data resolved during prepare");

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".resolved-content")
      .hasText("prepared", "the prepared data is rendered immediately");
    assert
      .dom(".d-block-skeleton")
      .doesNotExist("no skeleton, the data was already resolved");
    assert.strictEqual(
      resolveCalls,
      1,
      "render reused the prepared data without re-fetching"
    );
  });

  test("a block that declares no data renders without a loading boundary", async function (assert) {
    @block("no-data-block")
    class NoDataBlock extends Component {
      <template>
        <div class="plain-content">plain</div>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: NoDataBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".plain-content").hasText("plain");
    assert
      .dom(".d-block-skeleton")
      .doesNotExist("no skeleton for a plain block");
  });

  test("a failed resolution surfaces an error without crashing the outlet", async function (assert) {
    @block("data-error-block", {
      data: {
        request: () => DESCRIPTOR,
        resolve: () => Promise.reject(new Error("nope")),
      },
    })
    class DataErrorBlock extends Component {
      <template>
        <div class="resolved-content">{{@data}}</div>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: DataErrorBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".hero-blocks__block")
      .exists("the block wrapper still rendered (no crash)");
    assert
      .dom(".resolved-content")
      .doesNotExist("content is not shown for a failed resolution");
  });
});
