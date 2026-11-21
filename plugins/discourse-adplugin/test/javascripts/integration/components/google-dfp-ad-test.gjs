import { tracked } from "@glimmer/tracking";
import { run } from "@ember/runloop";
import { clearRender, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import GoogleDfpAd from "discourse/plugins/discourse-adplugin/discourse/components/google-dfp-ad";

class TestGoogleDfpAd extends GoogleDfpAd {
  didInsertElement() {
    super.didInsertElement(...arguments);
    this.set("loadedGoogletag", true);
    this.updated();
  }
}

module("Integration | Component | GoogleDfpAd", function (hooks) {
  setupRenderingTest(hooks, { anonymous: true, stubRouter: true });

  hooks.beforeEach(function () {
    this.siteSettings.dfp_publisher_id = "123";
    this.siteSettings.dfp_above_site_header_code = "default";
    this.siteSettings.dfp_above_site_header_ad_sizes = "728*90";
    this.siteSettings.dfp_target_above_site_header_key_code = "";
    this.siteSettings.dfp_target_above_site_header_value_code = "";
    this.siteSettings.ad_plugin_enable_tracking = false;
    this.site.set("dfp_category_settings", {
      1: { gam_adunit: "/123/travel", gam_keywords: "travel" },
      2: { gam_adunit: "/123/finance", gam_keywords: "finance" },
    });

    this.originalGoogletag = window.googletag;
    this.slots = [];
    this.refreshes = [];
    this.destroyed = [];
    const pubads = { refresh: (slots) => this.refreshes.push(...slots) };
    window.googletag = {
      cmd: { push: (callback) => callback() },
      defineSlot: (adUnitPath) => {
        const slot = {
          adUnitPath,
          targeting: {},
          setConfig({ targeting }) {
            Object.assign(this.targeting, targeting);
          },
          clearTargeting(key) {
            if (key === undefined) {
              this.targeting = {};
            } else {
              delete this.targeting[key];
            }
          },
          addService() {},
        };
        this.slots.push(slot);
        return slot;
      },
      pubads: () => pubads,
      display() {},
      destroySlots: (slots) => this.destroyed.push(...slots),
    };
  });

  hooks.afterEach(async function () {
    await clearRender();
    window.googletag = this.originalGoogletag;
  });

  test("reconciles the latest category after rapid navigation", async function (assert) {
    await render(
      <template><TestGoogleDfpAd @placement="above-site-header" /></template>
    );
    assert.strictEqual(this.refreshes.length, 1, "initial ad is requested");

    run(() => {
      this.owner.lookup("service:router").currentRoute = {
        attributes: { category: { id: 3, slug: "intermediate" } },
      };
    });
    assert.strictEqual(
      this.refreshes.length,
      1,
      "navigation respects the cooldown"
    );

    run(() => {
      this.owner.lookup("service:router").currentRoute = {
        attributes: { category: { id: 2, slug: "finance" } },
      };
    });
    await settled();

    assert.strictEqual(this.refreshes.length, 2, "the pending refresh runs");
    assert.strictEqual(
      this.refreshes.at(-1).adUnitPath,
      "/123/finance",
      "the slot uses the latest category unit"
    );
    assert.deepEqual(
      this.refreshes.at(-1).targeting.gam_keywords,
      ["finance"],
      "the slot uses the latest keywords"
    );
    assert.deepEqual(
      this.destroyed,
      [this.slots[0]],
      "the old unit is destroyed"
    );
  });

  test("live edits refresh a mounted slot and preserve third-party targeting", async function (assert) {
    await render(
      <template><TestGoogleDfpAd @placement="above-site-header" /></template>
    );
    const slot = this.slots[0];
    slot.setConfig({ targeting: { external: "preserved" } });

    this.owner.lookup("service:dfp-config").onSignal({
      public: { 1: { gam_adunit: "/123/travel" } },
      secure: false,
    });
    await settled();

    assert.strictEqual(
      this.refreshes.length,
      2,
      "the edit refreshes without navigation"
    );
    assert.strictEqual(this.slots.length, 1, "the same unit is reused");
    assert.strictEqual(
      slot.targeting.external,
      "preserved",
      "external targeting survives"
    );
    assert.false(
      Object.hasOwn(slot.targeting, "gam_keywords"),
      "removed plugin keywords are cleared"
    );
  });

  test("defines a new slot when the post number changes", async function (assert) {
    this.siteSettings.dfp_nth_post_code = 1;
    const postNumber = tracked(1);
    await render(
      <template>
        <TestGoogleDfpAd
          @placement="above-site-header"
          @postNumber={{postNumber.value}}
        />
      </template>
    );

    postNumber.value = 2;
    await settled();

    assert.strictEqual(
      this.slots.length,
      2,
      "the changed slot ID gets a GPT slot"
    );
    assert.strictEqual(this.refreshes.length, 2, "the new slot requests an ad");
  });

  test("cancels a pending refresh when the component is removed", async function (assert) {
    const visible = tracked(true);
    await render(
      <template>
        {{#if visible.value}}
          <TestGoogleDfpAd @placement="above-site-header" />
        {{/if}}
      </template>
    );

    run(() => {
      this.owner.lookup("service:router").currentRoute = {
        attributes: { category: { id: 2, slug: "finance" } },
      };
    });
    visible.value = false;
    await settled();

    assert.strictEqual(
      this.refreshes.length,
      1,
      "no ad is requested after removal"
    );
    assert.deepEqual(this.destroyed, this.slots, "the slot is destroyed");
  });
});
