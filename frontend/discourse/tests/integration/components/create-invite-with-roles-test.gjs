import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CreateInviteWithRoles from "discourse/components/modal/create-invite-with-roles";
import { withPluginApi } from "discourse/lib/plugin-api";
import Invite from "discourse/models/invite";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | CreateInviteWithRoles", function (hooks) {
  setupRenderingTest(hooks);

  test("hides the role toggle for users who can't create admin invites", async function (assert) {
    const model = {};

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    assert
      .dom(".create-invite-with-roles-modal__role-toggle")
      .doesNotExist("role toggle is not shown");
    assert.true(formKit().hasField("domain"), "defaults to member link mode");
  });

  test("shows the role toggle when the user can create admin invites", async function (assert) {
    this.currentUser.set("can_create_admin_invite", true);
    const model = {};

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    assert.dom(".create-invite-with-roles-modal__role-toggle").exists();
    assert
      .dom(".create-invite-with-roles-modal__role-toggle input[value='member']")
      .isChecked("defaults to the members tab");
  });

  test("defaults to the admins tab when the model asks for it", async function (assert) {
    this.currentUser.set("can_create_admin_invite", true);
    const model = { defaultRole: "admin" };

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    assert
      .dom(".create-invite-with-roles-modal__role-toggle input[value='admin']")
      .isChecked("defaults to the admins tab");
    assert.true(formKit().hasField("email"), "shows the email field");
    assert.false(
      formKit().hasField("domain"),
      "does not show the domain field"
    );
    assert.dom(".save-invite").hasText("Create & send");
  });

  test("ignores defaultRole for users who can't create admin invites", async function (assert) {
    const model = { defaultRole: "admin" };

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    assert.true(formKit().hasField("domain"), "stays in member mode");
  });

  test("creating an admin invite posts is_admin and shows the summary", async function (assert) {
    this.currentUser.set("can_create_admin_invite", true);
    const model = { defaultRole: "admin", invites: [] };

    let requestBody;
    pretender.post("/invites", (request) => {
      requestBody = new URLSearchParams(request.requestBody);
      return response({
        id: 42,
        invite_key: "abc123",
        link: "http://example.com/invites/abc123",
        email: "new-admin@example.com",
        is_admin: true,
        expires_at: "2100-01-01 00:00",
      });
    });

    let savedEventInvite;
    this.owner
      .lookup("service:app-events")
      .on("create-invite:saved", (invite) => (savedEventInvite = invite));

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    await formKit().field("email").fillIn("new-admin@example.com");
    await click(".save-invite");

    assert.strictEqual(requestBody.get("is_admin"), "true");
    assert.strictEqual(requestBody.get("email"), "new-admin@example.com");

    assert
      .dom(".create-invite-with-roles-modal__sent-to")
      .includesText("new-admin@example.com");
    assert
      .dom(".create-invite-with-roles-modal__link-share input.invite-link")
      .hasValue("http://example.com/invites/abc123");

    assert.strictEqual(model.invites.length, 1, "invite added to the list");
    assert.strictEqual(
      savedEventInvite?.id,
      42,
      "create-invite:saved app event fired"
    );
  });

  test("validates the admin email address", async function (assert) {
    this.currentUser.set("can_create_admin_invite", true);
    const model = { defaultRole: "admin" };

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    await formKit().field("email").fillIn("not-an-email");
    await click(".save-invite");

    assert.dom(".form-kit__errors").exists("shows a validation error");
  });

  test("creating a member link invite posts skip_email and shows the summary", async function (assert) {
    const model = { invites: [] };

    let requestBody;
    pretender.post("/invites", (request) => {
      requestBody = new URLSearchParams(request.requestBody);
      return response({
        id: 43,
        invite_key: "def456",
        link: "http://example.com/invites/def456",
        max_redemptions_allowed: 10,
        expires_at: "2100-01-01 00:00",
      });
    });

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    await click(".save-invite");

    assert.strictEqual(requestBody.get("skip_email"), "true");
    assert.notStrictEqual(requestBody.get("max_redemptions_allowed"), null);
    assert.strictEqual(requestBody.get("is_admin"), null);

    assert
      .dom(".create-invite-with-roles-modal__link-share input.invite-link")
      .hasValue("http://example.com/invites/def456");
  });

  test("sends the topic supplied by the model, like when sharing a topic", async function (assert) {
    const model = {
      inviteToTopic: true,
      topics: [{ id: 123, title: "A very interesting discussion" }],
      topicId: 123,
      topicTitle: "A very interesting discussion",
    };

    let requestBody;
    pretender.post("/invites", (request) => {
      requestBody = new URLSearchParams(request.requestBody);
      return response({
        id: 46,
        invite_key: "mno345",
        link: "http://example.com/invites/mno345",
        max_redemptions_allowed: 10,
        expires_at: "2100-01-01 00:00",
      });
    });

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    await click(".save-invite");

    assert.strictEqual(requestBody.get("topic_id"), "123");
  });

  test("creating a member email invite shows the invitation sent screen", async function (assert) {
    const model = { invites: [] };

    pretender.post("/invites", () =>
      response({
        id: 44,
        invite_key: "ghi789",
        link: "http://example.com/invites/ghi789",
        email: "someone@example.com",
        expires_at: "2100-01-01 00:00",
      })
    );

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    await click(
      ".create-invite-with-roles-modal__delivery input[value='email']"
    );
    await formKit().field("email").fillIn("someone@example.com");
    await click(".save-invite");

    assert
      .dom(".create-invite-with-roles-modal__email-sent")
      .includesText("someone@example.com");
    assert
      .dom(".create-invite-with-roles-modal__link-share")
      .doesNotExist("no copy link UI for email invites");
  });

  test("editing an existing admin invite locks the role toggle", async function (assert) {
    this.currentUser.set("can_create_admin_invite", true);
    const invite = Invite.create({
      id: 45,
      invite_key: "jkl012",
      link: "http://example.com/invites/jkl012",
      email: "admin@example.com",
      is_admin: true,
      expires_at: "2100-01-01 00:00",
    });
    const model = { editing: true, invite };

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    assert
      .dom(".create-invite-with-roles-modal__role-toggle input[value='admin']")
      .isChecked("admin tab selected");
    assert
      .dom(".create-invite-with-roles-modal__role-toggle input[value='member']")
      .isDisabled("member tab is locked");
    assert.dom(".save-invite").hasText("Update");
  });

  test("plugin outlet can disable the submit button in admin mode", async function (assert) {
    this.currentUser.set("can_create_admin_invite", true);
    const model = { defaultRole: "admin" };

    withPluginApi((api) => {
      api.renderInOutlet(
        "create-invite-admin-mode",
        <template>
          <button
            type="button"
            class="test-disable-submit"
            {{on "click" (fn @outletArgs.setSubmitDisabled true)}}
          >disable</button>
        </template>
      );
    });

    await render(
      <template>
        <CreateInviteWithRoles @inline={{true}} @model={{model}} />
      </template>
    );

    assert.dom(".save-invite").isNotDisabled();

    await click(".test-disable-submit");

    assert.dom(".save-invite").isDisabled();
  });
});
