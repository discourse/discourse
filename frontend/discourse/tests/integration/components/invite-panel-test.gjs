import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import InvitePanel from "discourse/components/invite-panel";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | invite-panel", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the invite link after it is generated", async function (assert) {
    const self = this;

    pretender.get("/u/search/users", () => response({ users: [] }));

    pretender.post("/invites", () =>
      response({
        link: "http://example.com/invites/92c297e886a0ca03089a109ccd6be155",
      })
    );

    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", {
      details: { can_invite_via_email: true },
    });
    this.set("inviteModel", user);

    await render(
      <template><InvitePanel @inviteModel={{self.inviteModel}} /></template>
    );

    const input = selectKit(".invite-user-input");
    await input.expand();
    await input.fillInFilter("eviltrout@example.com");
    await input.selectRowByValue("eviltrout@example.com");
    assert.dom(".send-invite").isEnabled();

    await click(".generate-invite-link");
    assert
      .dom(".invite-link-input")
      .hasValue("http://example.com/invites/92c297e886a0ca03089a109ccd6be155");
  });
});
