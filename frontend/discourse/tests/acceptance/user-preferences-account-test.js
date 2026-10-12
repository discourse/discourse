import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import DiscourseURL from "discourse/lib/url";
import pretender, {
  fixturesByUrl,
  response,
} from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("User Preferences - Account", function (needs) {
  needs.user({ can_upload_avatar: true });

  let customUserProps = {};
  let pickAvatarRequestData = null;
  const gravatarUploadId = 123456789;
  const associatedAccountAvatars = [
    {
      id: 12,
      name: "facebook",
      upload_id: 42,
      avatar_template: "/images/provider.png",
    },
    {
      id: 13,
      name: "github",
      upload_id: 43,
      avatar_template: "/images/another-provider.png",
    },
  ];

  needs.pretender((server, helper) => {
    server.get("/u/eviltrout.json", () => {
      const json = cloneJSON(fixturesByUrl["/u/eviltrout.json"]);
      Object.assign(json.user, {
        can_edit: true,
        can_edit_avatar: true,
        can_upload_avatar: true,
        associated_account_avatars: associatedAccountAvatars,
        ...customUserProps,
      });

      return helper.response(json);
    });

    server.delete("/u/eviltrout.json", () =>
      helper.response({ success: true })
    );

    server.post("/u/eviltrout/preferences/revoke-account", () => {
      return helper.response({
        success: true,
      });
    });

    server.put("/u/eviltrout/preferences/avatar/pick", (request) => {
      pickAvatarRequestData = helper.parsePostData(request.requestBody);
      return helper.response({ success: true });
    });

    server.post("/user_avatar/eviltrout/refresh_gravatar.json", () => {
      return helper.response({
        gravatar_upload_id: gravatarUploadId,
        gravatar_avatar_template: "/images/gravatar_is_not_avatar.png",
      });
    });
  });

  needs.hooks.afterEach(() => {
    customUserProps = {};
    pickAvatarRequestData = null;
  });

  test("changing username", async function (assert) {
    const stub = sinon
      .stub(DiscourseURL, "redirectTo")
      .withArgs("/u/good_trout/preferences");

    pretender.put("/u/eviltrout/preferences/username", (data) => {
      assert.strictEqual(data.requestBody, "new_username=good_trout");

      return response({
        id: fixturesByUrl["/u/eviltrout.json"].user.id,
        username: "good_trout",
      });
    });

    await visit("/u/eviltrout/preferences/account");

    assert.dom(".username-preference__current-username").hasText("eviltrout");

    await click(".username-preference__edit-username");

    assert.dom(".username-preference__input").hasValue("eviltrout");
    assert.dom(".username-preference__submit").isDisabled();

    await fillIn(".username-preference__input", "taken");
    assert.dom(".username-preference__submit").isDisabled();
    assert
      .dom(".pref-username .instructions")
      .includesText(i18n("user.change_username.taken"));

    await fillIn(".username-preference__input", "good_trout");
    assert.dom(".username-preference__submit").isEnabled();
    assert
      .dom(".pref-username .instructions")
      .doesNotIncludeText(i18n("user.change_username.taken"));

    await click(".username-preference__submit");
    await click(".dialog-container .btn-primary");

    sinon.assert.calledOnce(stub);
  });

  test("Delete dialog", async function (assert) {
    sinon.stub(DiscourseURL, "redirectAbsolute");

    customUserProps = {
      can_delete_account: true,
    };

    await visit("/u/eviltrout/preferences/account");
    await click(".delete-account .btn-danger");
    await click(".dialog-footer .btn-danger");

    assert
      .dom(".dialog-body")
      .hasText(i18n("user.deleted_yourself"), "confirmation dialog is shown");

    await click(".dialog-footer .btn-primary");

    assert.true(
      DiscourseURL.redirectAbsolute.calledWith("/"),
      "redirects to home after deleting"
    );
  });

  test("connected accounts", async function (assert) {
    await visit("/u/eviltrout/preferences/account");

    assert
      .dom(".pref-associated-accounts")
      .exists("has the connected accounts section");

    assert
      .dom(
        ".pref-associated-accounts table tr.facebook .associated-account__name"
      )
      .includesHtml("Facebook", "lists facebook");

    await click(
      ".pref-associated-accounts table tr.facebook .associated-account__actions .btn"
    );

    assert
      .dom(
        ".pref-associated-accounts table tr.facebook .associated-account__actions"
      )
      .includesHtml("Connect");
  });

  [
    { mode: "staff", user: { moderator: true }, access: "allowed" },
    { mode: "staff", user: {}, access: "restricted" },
    { mode: "no_one", user: { admin: true }, access: "restricted" },
    { mode: "tl3", user: { trust_level: 3 }, access: "allowed" },
    { mode: "tl3", user: { trust_level: 2 }, access: "restricted" },
    {
      mode: "tl3",
      user: { trust_level: 2, moderator: true },
      access: "allowed",
    },
  ].forEach(({ mode, user, access }) => {
    test(`avatar sources are ${access} in ${mode} mode for ${JSON.stringify(user)}`, async function (assert) {
      this.siteSettings.selectable_avatars_mode = mode;
      customUserProps = { admin: false, moderator: false, ...user };

      await visit("/u/eviltrout/preferences/account");
      await click(".pref-avatar .btn");

      assert.dom(".selectable-avatars").exists("offers the preset list");

      if (access === "allowed") {
        assert.dom("#uploaded-avatar").exists("allows uploaded pictures");
        assert
          .dom(".avatar-choice--associated-account")
          .exists({ count: 2 }, "allows provider pictures");
      } else {
        assert
          .dom("#uploaded-avatar")
          .doesNotExist("restricts uploaded pictures");
        assert
          .dom(".avatar-choice--associated-account")
          .doesNotExist("restricts provider pictures");
      }
    });
  });

  test("default avatar selector", async function (assert) {
    await visit("/u/eviltrout/preferences/account");
    await click(".pref-avatar .btn");

    assert.dom(".avatar-choice").exists("opens the avatar selection modal");

    await click(".avatar-selector-refresh-gravatar");

    assert
      .dom(".avatar[src='/images/gravatar_is_not_avatar.png']")
      .exists("displays the new gravatar image");

    await click("#gravatar");
    await click(".d-modal__footer .btn");

    assert.deepEqual(
      pickAvatarRequestData,
      {
        type: "gravatar",
        upload_id: `${gravatarUploadId}`,
      },
      "includes the right pick avatar request params"
    );
  });

  test("switching between connected accounts and an uploaded picture", async function (assert) {
    const avatarTemplate = associatedAccountAvatars[0].avatar_template;
    customUserProps = {
      avatar_template: avatarTemplate,
      custom_avatar_template: avatarTemplate,
      selected_user_associated_account_id: 12,
    };

    await visit("/u/eviltrout/preferences/account");
    await click(".pref-avatar .btn");

    assert
      .dom("#associated-account-avatar-12")
      .isChecked("prefers the recorded source over a matching upload");
    assert
      .dom("#current-avatar")
      .doesNotExist("does not duplicate the current picture");
    assert
      .dom('label[for="associated-account-avatar-12"]')
      .includesText("Facebook", "identifies the provider");
    assert
      .dom('label[for="associated-account-avatar-12"] img')
      .hasAttribute("src", avatarTemplate, "shows the provider preview");
    assert
      .dom(".avatar-choice--upload img")
      .hasAttribute("src", avatarTemplate, "keeps the uploaded preview");

    await click("#associated-account-avatar-13");
    await click(".d-modal__footer .btn-primary");

    assert.deepEqual(
      pickAvatarRequestData,
      {
        type: "associated_account",
        upload_id: "43",
        associated_account_id: "13",
      },
      "saves the other provider and its upload"
    );

    await click("#uploaded-avatar");
    await click(".d-modal__footer .btn-primary");

    assert.deepEqual(
      pickAvatarRequestData,
      {
        type: "custom",
        upload_id: "1573",
      },
      "switches back to the upload without retaining the provider selection"
    );
  });

  test("saving a current picture preserves it without replacing the uploaded picture", async function (assert) {
    this.siteSettings.selectable_avatars_mode = "everyone";
    this.siteSettings.selectable_avatars = ["/images/current.png"];
    customUserProps = {
      avatar_template: "/images/current.png",
      uploaded_avatar_id: 42,
      custom_avatar_template: "/images/uploaded.png",
      custom_avatar_upload_id: 43,
    };

    await visit("/u/eviltrout/preferences/account");
    await click(".pref-avatar .btn");

    assert
      .dom("#current-avatar")
      .isChecked("keeps the current picture selected");
    assert
      .dom('label[for="current-avatar"] img')
      .hasAttribute("src", "/images/current.png", "shows the current picture");
    await click(".d-modal__footer .btn-primary");

    assert.deepEqual(
      pickAvatarRequestData,
      { type: "current", upload_id: "42" },
      "preserves the current picture without replacing the saved upload"
    );
  });

  test("a site default picture stays selected with an empty preset list", async function (assert) {
    this.siteSettings.selectable_avatars_mode = "everyone";
    this.siteSettings.selectable_avatars = [];
    customUserProps = {
      avatar_template: "/images/site-default.png",
      uploaded_avatar_id: null,
      system_avatar_template: "/images/letter-avatar.png",
    };

    await visit("/u/eviltrout/preferences/account");
    await click(".pref-avatar .btn");

    assert.dom("#system-avatar").isChecked("selects the system source");
    assert
      .dom("#current-avatar")
      .doesNotExist("does not offer an empty current upload");
  });

  test("connected account avatars require avatar upload permission", async function (assert) {
    customUserProps = { can_upload_avatar: false };

    await visit("/u/eviltrout/preferences/account");
    await click(".pref-avatar .btn");

    assert
      .dom(".avatar-choice--associated-account")
      .doesNotExist("provider choices require the same permission as uploads");
  });
});

acceptance("User Preferences — Account - Download Archive", function (needs) {
  const currentUser = "eviltrout";
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/export_csv/export_entity.json", () => {
      return helper.response({});
    });
  });

  test("Can see and trigger download for account data", async function (assert) {
    await visit(`/u/${currentUser}/preferences/account`);

    assert.dom(".btn-request-archive").exists("button exists");

    await click(".btn-request-archive");
    await click("#dialog-holder .btn-primary");

    assert.dom(".dialog-body").hasText(i18n("user.download_archive.success"));

    await click("#dialog-holder .btn-primary");
  });
});
