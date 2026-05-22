import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _getOutletLayouts,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
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

    test("orders themes so the last row tails the theme stack", async function (assert) {
      withPluginApi((api) => {
        hydrateThemeBlockLayouts(api, [
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
        ]);
      });

      const resolved =
        await _getOutletLayouts().get("homepage-blocks").validatedLayout;
      assert.strictEqual(
        resolved[0].args.label,
        "second",
        "last theme in the stack wins resolution"
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

          // Re-instantiate `hydrateThemeBlockLayouts` is called inside the
          // subscription with `api` captured at subscribe time. Push a fresh
          // call now so we don't depend on stale `api` references in the
          // tracked map.
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
