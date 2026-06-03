import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { render, settled, waitFor } from "@ember/test-helpers";
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

  test("keeps chrome visible and shows the default skeleton while loading", async function (assert) {
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
        skeleton: () => ({ variant: "rect", count: 2 }),
      },
    })
    class DataSkeletonBlock extends Component {
      <template>
        <div class="block-chrome">chrome</div>
        <@Data>
          <:content as |value|>
            <div class="resolved-content">{{value}}</div>
          </:content>
        </@Data>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: DataSkeletonBlock }])
    );

    // A pending TrackedAsyncData keeps the run loop busy, so `settled()` would
    // block while the data loads. Wait for the rendered DOM instead.
    const renderPromise = render(
      <template><BlockOutlet @name="hero-blocks" /></template>
    );

    await waitFor(".d-skeleton");
    assert
      .dom(".block-chrome")
      .exists("the block's chrome stays visible while loading");
    assert
      .dom(".d-skeleton")
      .exists("the default reserved-space skeleton is shown");
    assert
      .dom(".block-data")
      .hasAttribute("aria-busy", "true", "the data region reports it is busy");
    assert.dom(".resolved-content").doesNotExist("no content yet");
    assert.strictEqual(resolveCalls, 1, "the resolver ran once");

    resolveFetch("hello");
    await renderPromise;
    await settled();

    assert.dom(".d-skeleton").doesNotExist("the skeleton is gone");
    assert.dom(".block-chrome").exists("the chrome is still there");
    assert
      .dom(".block-data")
      .hasAttribute("aria-busy", "false", "the region is no longer busy");
    assert
      .dom(".resolved-content")
      .hasText("hello", "the resolved data is rendered");
  });

  test("a block's :loading block overrides the default skeleton", async function (assert) {
    let resolveFetch;
    const fetchPromise = new Promise((resolve) => (resolveFetch = resolve));

    @block("data-custom-loading-block", {
      data: {
        request: () => DESCRIPTOR,
        resolve: () => fetchPromise,
      },
    })
    class DataCustomLoadingBlock extends Component {
      <template>
        <@Data>
          <:loading><div class="custom-skeleton">loading…</div></:loading>
          <:content as |value|>
            <div class="resolved-content">{{value}}</div>
          </:content>
        </@Data>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: DataCustomLoadingBlock }])
    );

    const renderPromise = render(
      <template><BlockOutlet @name="hero-blocks" /></template>
    );

    await waitFor(".custom-skeleton");
    assert.dom(".custom-skeleton").exists("the custom loading block renders");
    assert
      .dom(".d-skeleton")
      .doesNotExist("the default skeleton is not used when :loading is given");

    resolveFetch("done");
    await renderPromise;
    await settled();

    assert.dom(".resolved-content").hasText("done");
  });

  test("a resolved empty value renders the :empty block", async function (assert) {
    @block("data-empty-block", {
      data: {
        request: () => DESCRIPTOR,
        resolve: () => Promise.resolve(null),
      },
    })
    class DataEmptyBlock extends Component {
      <template>
        <@Data>
          <:content as |value|>
            <div class="resolved-content">{{value}}</div>
          </:content>
          <:empty><div class="empty-content">nothing here</div></:empty>
        </@Data>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: DataEmptyBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".empty-content")
      .exists("the empty block renders for null data");
    assert.dom(".resolved-content").doesNotExist("no content for empty data");
    assert.dom(".d-skeleton").doesNotExist("no skeleton once resolved");
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
        <@Data>
          <:content as |value|>
            <div class="resolved-content">{{value}}</div>
          </:content>
        </@Data>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: DataPreloadBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".resolved-content")
      .hasText("preloaded", "the preloaded payload is rendered");
    assert.dom(".d-skeleton").doesNotExist("no skeleton was shown");
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
        <@Data>
          <:content as |value|>
            <div class="resolved-content">{{value}}</div>
          </:content>
        </@Data>
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
      .dom(".d-skeleton")
      .doesNotExist("no skeleton, the data was already resolved");
    assert.strictEqual(
      resolveCalls,
      1,
      "render reused the prepared data without re-fetching"
    );
  });

  test("a descriptor arg change refetches and shows the skeleton instead of the stale data", async function (assert) {
    // Drive the descriptor off a tracked value the test controls, so changing
    // it mimics editing a data-affecting arg (a new key, hence a refetch).
    const state = new (class {
      @tracked count = 1;
    })();
    let resolveCalls = 0;
    const pendingResolvers = [];

    @block("data-refetch-block", {
      data: {
        request: () => ({ kind: "refetch", count: state.count }),
        resolve: () => {
          resolveCalls++;
          return new Promise((resolve) => pendingResolvers.push(resolve));
        },
      },
    })
    class DataRefetchBlock extends Component {
      <template>
        <@Data>
          <:content as |value|>
            <div class="resolved-content">{{value}}</div>
          </:content>
        </@Data>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: DataRefetchBlock }])
    );

    const renderPromise = render(
      <template><BlockOutlet @name="hero-blocks" /></template>
    );

    await waitFor(".d-skeleton");
    pendingResolvers[0]("first");
    await renderPromise;
    await settled();
    assert
      .dom(".resolved-content")
      .hasText("first", "the initial data is rendered");

    // Change the data-affecting arg: a new descriptor key, so a refetch starts.
    state.count = 2;
    await waitFor(".d-skeleton");

    assert.dom(".d-skeleton").exists("the skeleton shows during the refetch");
    assert
      .dom(".resolved-content")
      .doesNotExist("the stale data is not retained while refetching");
    assert.strictEqual(resolveCalls, 2, "the new descriptor triggered a fetch");

    pendingResolvers[1]("second");
    await settled();

    assert.dom(".d-skeleton").doesNotExist("the skeleton is gone");
    assert
      .dom(".resolved-content")
      .hasText("second", "the refetched data is rendered");
  });

  test("a failed resolution surfaces an inline error while chrome stays", async function (assert) {
    @block("data-error-block", {
      data: {
        request: () => DESCRIPTOR,
        resolve: () => Promise.reject(new Error("nope")),
      },
    })
    class DataErrorBlock extends Component {
      <template>
        <div class="block-chrome">chrome</div>
        <@Data>
          <:content as |value|>
            <div class="resolved-content">{{value}}</div>
          </:content>
        </@Data>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: DataErrorBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".block-chrome").exists("the chrome stays visible on failure");
    assert
      .dom(".resolved-content")
      .doesNotExist("content is not shown for a failed resolution");
    assert
      .dom(".hero-blocks__block .alert-error")
      .exists("the failure surfaces as an inline error rather than hanging");
  });

  test("a block that declares no data renders without a boundary", async function (assert) {
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
    assert.dom(".d-skeleton").doesNotExist("no skeleton for a plain block");
  });
});
