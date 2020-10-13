import EmberObject, { set } from "@ember/object";
import componentTest from "helpers/component-test";

moduleForComponent("invite-panel", { integration: true });

componentTest("can_invite_via_email", {
  template: "{{invite-panel panel=panel}}",

  beforeEach() {
    set(this.currentUser, "details", { can_invite_via_email: true });
    const inviteModel = JSON.parse(JSON.stringify(this.currentUser));
    this.set("panel", {
      id: "invite",
      model: { inviteModel: EmberObject.create(inviteModel) },
    });
  },

  async test(assert) {
    await fillIn(".invite-user-input", "eviltrout@example.com");
    assert.ok(find(".send-invite:disabled").length === 0);
  },
});
