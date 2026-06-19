import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _clearLayoutLayer,
  _getOutletLayouts,
  _resetOutletLayoutsForTesting,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import {
  hydrateThemeBlockLayouts,
  subscribeToBlockLayoutUpdates,
} from "discourse/plugins/discourse-wireframe/discourse/api-initializers/load-theme-block-layouts";

@block("wf:hydrate-test-tile", { args: { label: { type: "string" } } })
class HydrateTile extends Component {
  <template>
    <div>{{@label}}</div>
  </template>
}

module(
  "Unit | Discourse Wireframe | api-initializer:load-theme-block-layouts",
  function (hooks) {
    setupTest(hooks);

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
    });

    test("hydrates the theme layer for each row", async function (assert) {
      withPluginApi((api) => {
        hydrateThemeBlockLayouts(api, [
          {
            theme_id: 5,
            outlet: "homepage-blocks",
            layout: [{ block: HydrateTile, args: { label: "from-theme-5" } }],
          },
        ]);
      });

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(resolved[0].args.label, "from-theme-5");
    });

    test("owner is the most-ancestral theme (minimum stack rank)", async function (assert) {
      withPluginApi((api) => {
        hydrateThemeBlockLayouts(
          api,
          [
            {
              theme_id: 3,
              outlet: "homepage-blocks",
              layout: [{ block: HydrateTile, args: { label: "first" } }],
            },
            {
              theme_id: 7,
              outlet: "homepage-blocks",
              layout: [{ block: HydrateTile, args: { label: "second" } }],
            },
          ],
          { 3: { stack_index: 0 }, 7: { stack_index: 1 } }
        );
      });

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(
        resolved[0].args.label,
        "first",
        "the parent theme (minimum stack rank) owns the outlet"
      );
    });

    test("a live update for a lower-ranked theme doesn't steal ownership", async function (assert) {
      const meta = { 3: { stack_index: 0 }, 7: { stack_index: 1 } };
      withPluginApi((api) => {
        // Boot: parent theme 3 (rank 0) owns; component theme 7 (rank 1) loses.
        hydrateThemeBlockLayouts(
          api,
          [
            {
              theme_id: 3,
              outlet: "homepage-blocks",
              layout: [{ block: HydrateTile, args: { label: "parent" } }],
            },
            {
              theme_id: 7,
              outlet: "homepage-blocks",
              layout: [{ block: HydrateTile, args: { label: "child" } }],
            },
          ],
          meta
        );
        subscribeToBlockLayoutUpdates(api, [3, 7], meta);
      });

      // A live update for the lower-ranked component theme 7 arrives over the
      // real MessageBus channel it subscribed to.
      await publishToMessageBus("/block-layouts/7", {
        theme_id: 7,
        outlet: "homepage-blocks",
        layout: [{ block: HydrateTile, args: { label: "child-updated" } }],
        schema_version: 1,
      });

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(
        resolved[0].args.label,
        "parent",
        "the parent (minimum stack rank) still owns after a component's live update"
      );

      // Prove the update actually landed on theme 7 (not a silent no-op): drop
      // the parent and the component's freshly-published layout resolves.
      _clearLayoutLayer("homepage-blocks", LAYOUT_LAYERS.THEME, { themeId: 3 });
      const afterParentCleared =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(
        afterParentCleared[0].args.label,
        "child-updated",
        "the live update was delivered to the component theme"
      );
    });

    test("ignores rows without a theme_id, outlet, or layout", function (assert) {
      withPluginApi((api) => {
        hydrateThemeBlockLayouts(api, [
          { theme_id: 5, outlet: "homepage-blocks" },
          { theme_id: 5, layout: [] },
          { outlet: "homepage-blocks", layout: [] },
        ]);
      });

      assert.strictEqual(_getOutletLayouts().size, 0);
    });

    test("noops on empty / null input", function (assert) {
      withPluginApi((api) => {
        hydrateThemeBlockLayouts(api, null);
        hydrateThemeBlockLayouts(api, []);
      });

      assert.strictEqual(_getOutletLayouts().size, 0);
    });

    test("subscribeToBlockLayoutUpdates subscribes per theme id", async function (assert) {
      const messageBus = getOwner(this).lookup("service:message-bus");
      const subscriptions = [];
      const originalSubscribe = messageBus.subscribe.bind(messageBus);
      messageBus.subscribe = (channel, callback) => {
        subscriptions.push({ channel, callback });
      };

      try {
        withPluginApi((api) => {
          subscribeToBlockLayoutUpdates(api, [3, 7]);
        });

        assert.deepEqual(
          subscriptions.map((s) => s.channel),
          ["/block-layouts/3", "/block-layouts/7"]
        );

        // Drive a fake message into the subscription for theme 3 — it
        // should publish into the resolved layout.
        withPluginApi((api) => {
          subscriptions[0].callback({
            theme_id: 3,
            outlet: "homepage-blocks",
            layout: [{ block: HydrateTile, args: { label: "from-bus" } }],
            schema_version: 1,
          });
          // `api` is captured by the subscription's closure; we just
          // need to be inside withPluginApi for the assertion below.
          void api;
        });

        const resolved =
          await _getOutletLayouts().get("homepage-blocks").validatedLayout;
        assert.strictEqual(resolved[0].args.label, "from-bus");
      } finally {
        messageBus.subscribe = originalSubscribe;
      }
    });

    test("subscription handler ignores foreign theme_ids", async function (assert) {
      const messageBus = getOwner(this).lookup("service:message-bus");
      let subscribed;
      const originalSubscribe = messageBus.subscribe.bind(messageBus);
      messageBus.subscribe = (_channel, callback) => {
        subscribed = callback;
      };

      try {
        withPluginApi((api) => {
          subscribeToBlockLayoutUpdates(api, [3]);
        });

        subscribed({
          theme_id: 999, // not the subscribed id
          outlet: "homepage-blocks",
          layout: [{ block: HydrateTile, args: { label: "ignored" } }],
        });

        assert.strictEqual(_getOutletLayouts().size, 0);
      } finally {
        messageBus.subscribe = originalSubscribe;
      }
    });
  }
);
