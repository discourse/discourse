import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import PreloadStore from "discourse/lib/preload-store";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

function setAuthenticationData(hooks, json) {
  hooks.beforeEach(() => {
    const node = document.createElement("meta");
    node.dataset.authenticationData = JSON.stringify(json);
    node.id = "data-authentication";
    document.querySelector("head").appendChild(node);
  });
  hooks.afterEach(() => {
    document
      .querySelector("head")
      .removeChild(document.getElementById("data-authentication"));
  });
}

function preloadInvite({
  link = false,
  email_verified_by_link = false,
  different_external_email = false,
  hidden_email = false,
} = {}) {
  const info = {
    invited_by: {
      id: 123,
      username: "foobar",
      avatar_template: "/user_avatar/localhost/neil/{size}/25_1.png",
      name: "foobar",
      title: "team",
    },
    username: "invited",
    email_verified_by_link,
    different_external_email,
    hidden_email,
  };

  if (link) {
    info.email = "null";
    info.is_invite_link = true;
  } else {
    info.email = "foobar@example.com";
    info.is_invite_link = false;
  }

  PreloadStore.store("invite_info", info);
}

acceptance("Invite accept", function (needs) {
  needs.settings({ full_name_required: true });

  test("email invite link", async function (assert) {
    PreloadStore.store("invite_info", {
      invited_by: {
        id: 123,
        username: "foobar",
        avatar_template: "/user_avatar/localhost/neil/{size}/25_1.png",
        name: "foobar",
        title: "team",
      },
      email: "foobar@example.com",
      username: "invited",
      is_invite_link: false,
    });

    await visit("/invites/my-valid-invite-token");

    assert
      .dom(".col-form")
      .includesText(
        i18n("invites.social_login_available"),
        "shows social login hint"
      );

    assert.dom("#new-account-email").doesNotExist("hides the email input");
  });

  test("invite link", async function (assert) {
    this.siteSettings.login_required = true;
    PreloadStore.store("invite_info", {
      invited_by: {
        id: 123,
        username: "neil",
        avatar_template: "/user_avatar/localhost/neil/{size}/25_1.png",
        name: "Neil Lalonde",
        title: "team",
      },
      email: null,
      username: "invited",
      is_invite_link: true,
    });

    await visit("/invites/my-valid-invite-token");

    assert
      .dom(document.body)
      .hasNoClass(
        "has-sidebar-page",
        "does not display the sidebar on the invites page"
      );

    assert
      .dom(".d-header")
      .doesNotExist("does not display the site header on the invites page");

    assert.dom("#new-account-email").exists("shows the email input");
    assert.dom("#new-account-username").exists("shows the username input");
    assert
      .dom("#new-account-username")
      .hasValue("invited", "username is prefilled");
    assert.dom("#new-account-name").exists("shows the name input");
    assert.dom("#new-account-password").exists("shows the password input");
    assert
      .dom(".invites-show .btn-primary")
      .isDisabled("submit is disabled because name and email is not filled");
    assert
      .dom("#new-account-password")
      .hasAttribute("type", "password", "password is masked by default");

    await click(".toggle-password-mask");
    assert
      .dom("#new-account-password")
      .hasAttribute(
        "type",
        "text",
        "password is unmasked when toggle is clicked"
      );

    await fillIn("#new-account-name", "John Doe");
    assert
      .dom(".invites-show .btn-primary")
      .isDisabled("submit is disabled because email is not filled");

    await fillIn("#new-account-email", "john.doe@example.com");
    assert
      .dom(".invites-show .btn-primary")
      .isDisabled("submit is disabled because password is not filled");

    await fillIn("#new-account-password", "top$ecretzz");
    assert.dom(".invites-show .btn-primary").isEnabled("submit is enabled");

    await fillIn("#new-account-username", "a");
    assert.dom(".username-input .bad").exists("username is not valid");
    assert.dom(".invites-show .btn-primary").isDisabled("submit is disabled");

    await fillIn("#new-account-password", "aaa");
    assert.dom(".password-input .bad").exists("password is not valid");
    assert.dom(".invites-show .btn-primary").isDisabled("submit is disabled");

    await fillIn("#new-account-email", "john.doe@example");
    assert.dom(".email-input .bad").exists("email is not valid");
    assert.dom(".invites-show .btn-primary").isDisabled("submit is disabled");

    await fillIn("#new-account-username", "valid-name");
    await fillIn("#new-account-password", "secur3ty4Y0uAndMe");
    await fillIn("#new-account-email", "john.doe@example.com");
    assert.dom(".username-input .good").exists("username is valid");
    assert.dom(".password-input .good").exists("password is valid");
    assert.dom(".email-input .good").exists("email is valid");
    assert.dom(".invites-show .btn-primary").isEnabled("submit is enabled");
  });

  test("invite name is required only if full name is required", async function (assert) {
    preloadInvite();
    await visit("/invites/my-valid-invite-token");
    assert
      .dom(".name-input .required")
      .doesNotExist("Full name is implicitly required");
  });
});

acceptance("Invite accept when local login is disabled", function (needs) {
  needs.settings({ enable_local_logins: false });

  test("invite link", async function (assert) {
    preloadInvite({ link: true });

    await visit("/invites/my-valid-invite-token");

    assert.dom(".btn-social.facebook").exists("shows Facebook login button");
    assert.dom("form").doesNotExist("does not display the form");
  });

  test("email invite link", async function (assert) {
    preloadInvite();
    await visit("/invites/my-valid-invite-token");

    assert.dom(".btn-social.facebook").exists("shows Facebook login button");
    assert.dom("form").doesNotExist("does not display the form");
  });
});

acceptance(
  "Invite accept when DiscourseConnect SSO is enabled and local login is disabled",
  function (needs) {
    needs.settings({
      enable_local_logins: false,
      enable_discourse_connect: true,
    });

    test("invite link", async function (assert) {
      preloadInvite({ link: true });

      await visit("/invites/my-valid-invite-token");

      assert
        .dom(".btn-social.facebook")
        .doesNotExist("does not show Facebook login button");
      assert.dom("form").doesNotExist("does not display the form");
      assert
        .dom(".email-message")
        .doesNotExist(
          "does not show the email message with the prefilled email"
        );
      assert.dom(".discourse-connect").exists("shows the Continue button");
    });

    test("email invite link", async function (assert) {
      preloadInvite();

      await visit("/invites/my-valid-invite-token");

      assert
        .dom(".btn-social.facebook")
        .doesNotExist("does not show Facebook login button");
      assert.dom("form").doesNotExist("does not display the form");
      assert
        .dom(".email-message")
        .exists("shows the email message with the prefilled email");
      assert.dom(".discourse-connect").exists("shows the Continue button");
      assert.dom(".email-message").includesText("foobar@example.com");
    });
  }
);

acceptance(
  "Invite accept when DiscourseConnect SSO is enabled and local login is enabled (bad config)",
  function (needs) {
    needs.settings({
      enable_local_logins: true,
      enable_discourse_connect: true,
    });

    test("invite link", async function (assert) {
      preloadInvite({ link: true });

      await visit("/invites/my-valid-invite-token");
      assert.dom("form").doesNotExist("does not display the form");
    });
  }
);

acceptance("Invite link with authentication data", function (needs) {
  needs.settings({ enable_local_logins: false });

  setAuthenticationData(needs.hooks, {
    auth_provider: "facebook",
    email: "blah@example.com",
    email_valid: true,
    username: "foobar",
    name: "barfoo",
  });

  test("form elements and buttons are correct ", async function (assert) {
    preloadInvite({ link: true });

    await visit("/invites/my-valid-invite-token");

    assert
      .dom(".btn-social.facebook")
      .doesNotExist("does not show Facebook login button");

    assert
      .dom("#new-account-password")
      .doesNotExist("does not show password field");

    assert.dom("#new-account-email").isDisabled("email field is disabled");

    assert
      .dom("#account-email-validation")
      .hasText(i18n("user.email.authenticated", { provider: "Facebook" }));

    assert
      .dom("#new-account-username")
      .hasValue("foobar", "username is prefilled");

    assert.dom("#new-account-name").hasValue("barfoo", "name is prefilled");
  });
});

acceptance("Email Invite link with authentication data", function (needs) {
  needs.settings({ enable_local_logins: false });

  setAuthenticationData(needs.hooks, {
    auth_provider: "facebook",
    email: "blah@example.com",
    email_valid: true,
    username: "foobar",
    name: "barfoo",
  });

  test("email invite link with authentication data when email does not match", async function (assert) {
    preloadInvite();

    await visit("/invites/my-valid-invite-token");

    assert
      .dom("#account-email-validation")
      .hasText(
        i18n("user.email.invite_auth_email_invalid", { provider: "Facebook" })
      );

    assert.dom("form").doesNotExist("does not display the form");
  });
});

acceptance(
  "Email Invite link with valid authentication data",
  function (needs) {
    needs.settings({ enable_local_logins: false });

    setAuthenticationData(needs.hooks, {
      auth_provider: "facebook",
      email: "foobar@example.com",
      email_valid: true,
      username: "foobar",
      name: "barfoo",
    });

    test("confirm form and buttons", async function (assert) {
      preloadInvite();

      await visit("/invites/my-valid-invite-token");

      assert
        .dom(".btn-social.facebook")
        .doesNotExist("does not show Facebook login button");

      assert
        .dom("#new-account-password")
        .doesNotExist("does not show password field");
      assert
        .dom("#new-account-email")
        .doesNotExist("does not show email field");

      assert
        .dom("#account-email-validation")
        .hasText(i18n("user.email.authenticated", { provider: "Facebook" }));

      assert
        .dom("#new-account-username")
        .hasValue("foobar", "username is prefilled");

      assert.dom("#new-account-name").hasValue("barfoo", "name is prefilled");
    });
  }
);

acceptance(
  "Email Invite link with different external email address",
  function (needs) {
    needs.settings({ enable_local_logins: false });

    setAuthenticationData(needs.hooks, {
      auth_provider: "facebook",
      email: "foobar+different@example.com",
      email_valid: true,
      username: "foobar",
      name: "barfoo",
    });

    test("display information that email is invalid", async function (assert) {
      preloadInvite({ different_external_email: true, hidden_email: true });

      await visit("/invites/my-valid-invite-token");

      assert
        .dom(".bad")
        .hasText(
          "Your invitation email does not match the email authenticated by Facebook"
        );
    });
  }
);

acceptance(
  "Email Invite link with valid authentication data, valid email token, unverified authentication email",
  function (needs) {
    needs.settings({ enable_local_logins: false });

    setAuthenticationData(needs.hooks, {
      auth_provider: "facebook",
      email: "foobar@example.com",
      email_valid: false,
      username: "foobar",
      name: "barfoo",
    });

    test("confirm form and buttons", async function (assert) {
      preloadInvite({ email_verified_by_link: true });

      await visit("/invites/my-valid-invite-token");

      assert
        .dom("#new-account-email")
        .doesNotExist("does not show email field");

      assert
        .dom("#account-email-validation")
        .hasText(i18n("user.email.authenticated_by_invite"));
    });
  }
);

acceptance(
  "Email Invite link with valid authentication data, no email token, unverified authentication email",
  function (needs) {
    needs.settings({ enable_local_logins: false });

    setAuthenticationData(needs.hooks, {
      auth_provider: "facebook",
      email: "foobar@example.com",
      email_valid: false,
      username: "foobar",
      name: "barfoo",
    });

    test("confirm form and buttons", async function (assert) {
      preloadInvite({ email_verified_by_link: false });

      await visit("/invites/my-valid-invite-token");

      assert
        .dom("#new-account-email")
        .doesNotExist("does not show email field");

      assert.dom("#account-email-validation").hasText(i18n("user.email.ok"));
    });
  }
);

acceptance(
  "Invite link with authentication data, and associate link",
  function (needs) {
    needs.settings({ enable_local_logins: false });

    setAuthenticationData(needs.hooks, {
      auth_provider: "facebook",
      email: "blah@example.com",
      email_valid: true,
      username: "foobar",
      name: "barfoo",
      associate_url: "/associate/abcde",
    });

    test("shows the associate link", async function (assert) {
      preloadInvite({ link: true });

      await visit("/invites/my-valid-invite-token");

      assert
        .dom(".create-account-associate-link")
        .exists("shows the associate account link");
    });
  }
);

acceptance("Associate link", function (needs) {
  needs.user();
  needs.settings({ enable_local_logins: false });

  setAuthenticationData(needs.hooks, {
    auth_provider: "facebook",
    email: "blah@example.com",
    email_valid: true,
    username: "foobar",
    name: "barfoo",
    associate_url: "/associate/abcde",
  });

  test("associates the account", async function (assert) {
    preloadInvite({ link: true });
    pretender.get("/associate/abcde.json", () => {
      return response({
        token: "abcde",
        provider_name: "facebook",
      });
    });

    pretender.post("/associate/abcde", () => {
      return response({ success: true });
    });

    await visit("/invites/my-valid-invite-token");
    assert
      .dom(".create-account-associate-link")
      .exists("shows the associate account link");

    await click(".create-account-associate-link a");
    assert.dom(".d-modal").exists();

    await click(".d-modal .btn-primary");
    assert.strictEqual(currentURL(), "/u/eviltrout/preferences/account");
  });
});

acceptance("Associate link, with an error", function (needs) {
  needs.user();
  needs.settings({ enable_local_logins: false });

  setAuthenticationData(needs.hooks, {
    auth_provider: "facebook",
    email: "blah@example.com",
    email_valid: true,
    username: "foobar",
    name: "barfoo",
    associate_url: "/associate/abcde",
  });

  test("shows the error", async function (assert) {
    preloadInvite({ link: true });
    pretender.get("/associate/abcde.json", () => {
      return response({
        token: "abcde",
        provider_name: "facebook",
      });
    });

    pretender.post("/associate/abcde", () => {
      return response({ error: "sorry, no" });
    });

    await visit("/invites/my-valid-invite-token");
    await click(".create-account-associate-link a");
    await click(".d-modal .btn-primary");

    assert.dom(".d-modal .alert").hasText("sorry, no");
  });
});
