import { settled } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function mapTracker(authorizedMap) {
  const state = { fetched: 0, lastBody: authorizedMap };
  pretender.get("/ad_plugin/dfp_category_settings", () => {
    state.fetched++;
    return response(state.lastBody);
  });
  return state;
}

acceptance("dfp-config service | anonymous", function () {
  test("applies the public map immediately and never fetches", async function (assert) {
    const tracker = mapTracker({});
    const site = this.owner.lookup("service:site");
    site.set("dfp_category_settings", { old: true });

    this.owner.lookup("service:dfp-config").onSignal({
      public: { 5: { gam_adunit: "/public" } },
      secure: true,
    });

    assert.propEqual(
      site.get("dfp_category_settings"),
      { 5: { gam_adunit: "/public" } },
      "public map applied directly (complete for anonymous viewers)"
    );
    assert.strictEqual(tracker.fetched, 0, "no authenticated refetch");
  });
});

acceptance("dfp-config service | logged-in member", function (needs) {
  needs.user();

  test("with no private config, applies the public map and does not fetch", async function (assert) {
    const tracker = mapTracker({});
    updateCurrentUser({ admin: false, moderator: false, trust_level: 1 });
    const site = this.owner.lookup("service:site");

    this.owner.lookup("service:dfp-config").onSignal({
      public: { 5: { gam_adunit: "/public" } },
      secure: false,
    });

    assert.propEqual(
      site.get("dfp_category_settings"),
      { 5: { gam_adunit: "/public" } },
      "public map applied (complete when nothing is private)"
    );
    assert.strictEqual(
      tracker.fetched,
      0,
      "no fetch when there is no private config"
    );
  });

  test("with private config, fetches the authorized map instead of clobbering with public", async function (assert) {
    // the member's authorized map includes a private category the public set omits
    const authorized = {
      5: { gam_adunit: "/public" },
      9: { gam_adunit: "/private-visible-to-this-member" },
    };
    const tracker = mapTracker(authorized);
    updateCurrentUser({ admin: false, moderator: false, trust_level: 1 });
    const site = this.owner.lookup("service:site");
    const before = { prior: true };
    site.set("dfp_category_settings", before);

    this.owner.lookup("service:dfp-config").onSignal({
      public: { 5: { gam_adunit: "/public" } },
      secure: true,
    });

    assert.propEqual(
      site.get("dfp_category_settings"),
      before,
      "the public subset is NOT applied on top of the member's existing map"
    );

    // let the jittered fetch fire and settle (JITTER_MS is 3000)
    await sleep(3200);
    await settled();

    assert.strictEqual(
      tracker.fetched,
      1,
      "the member issued one authenticated refetch"
    );
    assert.propEqual(
      site.get("dfp_category_settings"),
      authorized,
      "the fetched per-viewer map (including the private category) is applied"
    );
  });
});
