import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import User from "discourse/models/user";

module("Integration | Component | invite-panel", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the invite link after it is generated", async function (assert) {
    pretender.get("/u/search/users", () => response({ users: [] }));

    pretender.post("/invites", () =>
      response({
        link: "http://example.com/invites/92c297e886a0ca03089a109ccd6be155",
      })
    );

    this.currentUser.set("details", { can_invite_via_email: true });
    this.set("panel", {
      id: "invite",
      model: { inviteModel: User.create(this.currentUser) },
    });

    await render(hbs`<InvitePanel @panel={{this.panel}} />`);

    const input = selectKit(".invite-user-input");
    await input.expand();
    await input.fillInFilter("eviltrout@example.com");
    await input.selectRowByValue("eviltrout@example.com");
    assert.ok(!exists(".send-invite:disabled"));

    await click(".generate-invite-link");
    assert.strictEqual(
      query(".invite-link-input").value,
      "http://example.com/invites/92c297e886a0ca03089a109ccd6be155"
    );
  });
});
