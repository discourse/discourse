import selectKit from "helpers/select-kit-helper";
import componentTest from "helpers/component-test";

moduleForComponent("badge-title", { integration: true });

componentTest("badge title", {
  template:
    "{{badge-title selectableUserBadges=selectableUserBadges user=user}}",

  beforeEach() {
    this.set("subject", selectKit());
    this.set("selectableUserBadges", [
      Ember.Object.create({
        badge: { name: "(none)" }
      }),
      Ember.Object.create({
        id: 42,
        badge_id: 102,
        badge: { name: "Test" }
      })
    ]);
  },

  async test(assert) {
    /* global server */
    server.put("/u/eviltrout/preferences/badge_title", () => [
      200,
      { "Content-Type": "application/json" },
      {}
    ]);
    await this.subject.expand();
    await this.subject.selectRowByValue(42);
    await click(".btn");
    assert.equal(this.currentUser.title, "Test");
  }
});
