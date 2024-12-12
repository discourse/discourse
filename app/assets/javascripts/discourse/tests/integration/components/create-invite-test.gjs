import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CreateInvite from "discourse/components/modal/create-invite";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | CreateInvite", function (hooks) {
  setupRenderingTest(hooks);

  test("typing an email address in the restrictTo field", async function (assert) {
    const model = {};

    await render(<template>
      <CreateInvite @inline={{true}} @model={{model}} />
    </template>);

    await click(".edit-link-options");

    assert.false(
      formKit().hasField("customMessage"),
      "customMessage field is not shown before typing an email address in the restrictTo field"
    );
    assert.true(
      formKit().hasField("maxRedemptions"),
      "maxRedemptions field is shown before typing an email address in the restrictTo field"
    );
    assert
      .dom(".save-invite-and-send-email")
      .doesNotExist(
        "'Create invite and send email' button is not shown before typting an email address in the restrictTo field"
      );
    assert
      .dom(".save-invite")
      .exists(
        "'Create invite' button is shown before typting an email address in the restrictTo field"
      );

    await formKit().field("restrictTo").fillIn("discourse@example.com");

    assert.true(
      formKit().hasField("customMessage"),
      "customMessage field is shown after typing an email address in the restrictTo field"
    );
    assert.false(
      formKit().hasField("maxRedemptions"),
      "maxRedemptions field is not shown after typing an email address in the restrictTo field"
    );
    assert
      .dom(".save-invite-and-send-email")
      .exists(
        "'Create invite and send email' button is shown after typting an email address in the restrictTo field"
      );
    assert
      .dom(".save-invite")
      .exists(
        "'Create invite' button is shown after typting an email address in the restrictTo field"
      );
  });

  test("the inviteToTopic field", async function (assert) {
    const model = {};
    this.currentUser.admin = true;
    this.siteSettings.must_approve_users = true;

    await render(<template>
      <CreateInvite @inline={{true}} @model={{model}} />
    </template>);
    await click(".edit-link-options");

    assert.false(
      formKit().hasField("inviteToTopic"),
      "inviteToTopic field is not shown to admins if must_approve_users is true"
    );

    this.siteSettings.must_approve_users = false;
    await render(<template>
      <CreateInvite @inline={{true}} @model={{model}} />
    </template>);
    await click(".edit-link-options");

    assert.true(
      formKit().hasField("inviteToTopic"),
      "inviteToTopic field is shown to admins if must_approve_users is false"
    );

    this.currentUser.set("admin", false);
    this.currentUser.set("moderator", false);
    await render(<template>
      <CreateInvite @inline={{true}} @model={{model}} />
    </template>);
    await click(".edit-link-options");

    assert.false(
      formKit().hasField("inviteToTopic"),
      "inviteToTopic field is not shown to regular users"
    );
  });

  test("the maxRedemptions field for non-staff users", async function (assert) {
    const model = {};
    this.siteSettings.invite_link_max_redemptions_limit_users = 11;

    await render(<template>
      <CreateInvite @inline={{true}} @model={{model}} />
    </template>);
    await click(".edit-link-options");

    assert.strictEqual(
      formKit().field("maxRedemptions").value(),
      10,
      "uses 10 as the default value if invite_link_max_redemptions_limit_users is larger than 10"
    );

    this.siteSettings.invite_link_max_redemptions_limit_users = 9;

    await render(<template>
      <CreateInvite @inline={{true}} @model={{model}} />
    </template>);
    await click(".edit-link-options");

    assert.strictEqual(
      formKit().field("maxRedemptions").value(),
      9,
      "uses invite_link_max_redemptions_limit_users as the default value if it's smaller than 10"
    );
  });

  test("the maxRedemptions field for staff users", async function (assert) {
    const model = {};
    this.currentUser.set("moderator", true);
    this.siteSettings.invite_link_max_redemptions_limit = 111;

    await render(<template>
      <CreateInvite @inline={{true}} @model={{model}} />
    </template>);
    await click(".edit-link-options");

    assert.strictEqual(
      formKit().field("maxRedemptions").value(),
      100,
      "uses 100 as the default value if invite_link_max_redemptions_limit is larger than 100"
    );

    this.siteSettings.invite_link_max_redemptions_limit = 98;

    await render(<template>
      <CreateInvite @inline={{true}} @model={{model}} />
    </template>);
    await click(".edit-link-options");

    assert.strictEqual(
      formKit().field("maxRedemptions").value(),
      98,
      "uses invite_link_max_redemptions_limit as the default value if it's smaller than 10"
    );
  });

  test("the expiresAfterDays field", async function (assert) {
    const model = {};
    this.siteSettings.invite_expiry_days = 3;

    await render(<template>
      <CreateInvite @inline={{true}} @model={{model}} />
    </template>);
    await click(".edit-link-options");

    assert.deepEqual(
      formKit().field("expiresAfterDays").options(),
      ["__NONE__", "1", "3", "7", "30", "90", "999999"],
      "the value of invite_expiry_days is added to the dropdown"
    );

    this.siteSettings.invite_expiry_days = 90;

    await render(<template>
      <CreateInvite @inline={{true}} @model={{model}} />
    </template>);
    await click(".edit-link-options");

    assert.deepEqual(
      formKit().field("expiresAfterDays").options(),
      ["__NONE__", "1", "7", "30", "90", "999999"],
      "the value of invite_expiry_days is not added to the dropdown if it's already one of the options"
    );
  });
});
