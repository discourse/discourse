import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function setupAuthData(data) {
  data = {
    auth_provider: "test",
    email: "blah@example.com",
    username: "testuser",
    can_edit_username: true,
    can_edit_name: true,
    ...data,
  };

  const node = document.createElement("meta");
  node.dataset.authenticationData = JSON.stringify(data);
  node.id = "data-authentication";
  document.querySelector("head").appendChild(node);
}

for (const { active, destination, expected } of [
  { active: false, destination: "/", expected: "/u/account-created" },
  { active: false, destination: "/login", expected: "/u/account-created" },
  { active: true, destination: "/latest", expected: "/latest" },
  { active: true, destination: "/signup", expected: "/u/account-created" },
]) {
  acceptance(
    `Create Account - external auth redirects (active=${active}, destination=${destination})`,
    function (needs) {
      needs.hooks.beforeEach(function () {
        setupAuthData({ destination_url: destination });
        this.loginForm = document.createElement("form");
        this.loginForm.id = "hidden-login-form";
        for (const name of ["username", "password", "redirect"]) {
          const input = document.createElement("input");
          input.name = name;
          this.loginForm.appendChild(input);
        }
        document.body.appendChild(this.loginForm);
        this.submit = sinon.stub(this.loginForm, "submit");
      });

      needs.hooks.afterEach(function () {
        this.loginForm.remove();
        document.getElementById("data-authentication").remove();
      });

      test("redirects after signup", async function (assert) {
        pretender.post("/u", () => response({ success: true, active }));

        await visit("/");
        await click(".signup-fullpage .btn-primary");

        assert.true(
          this.submit.calledOnce,
          "submits the browser redirect form"
        );
        assert.strictEqual(
          this.loginForm.elements.redirect.value,
          expected,
          "inactive signups see confirmation while active signups retain their destination"
        );
      });
    }
  );
}

acceptance("Create Account - external auth", function (needs) {
  needs.hooks.beforeEach(function () {
    setupAuthData();
  });
  needs.hooks.afterEach(function () {
    document.getElementById("data-authentication").remove();
  });

  test("when skip is disabled (default)", async function (assert) {
    await visit("/");

    assert.dom(".signup-fullpage").exists("it shows the signup page");

    assert.dom("#new-account-username").exists("it shows the fields");

    assert
      .dom(".create-account-associate-link")
      .doesNotExist("it does not show the associate link");
  });

  test("when skip is enabled", async function (assert) {
    this.siteSettings.auth_skip_create_confirm = true;
    await visit("/");

    assert.dom(".signup-fullpage").exists("it shows the signup page");

    assert
      .dom("#new-account-username")
      .doesNotExist("it does not show the fields");
  });
});

acceptance(
  "Create Account - external auth without username suggestion",
  function (needs) {
    needs.hooks.beforeEach(function () {
      setupAuthData({ username: null });
    });
    needs.hooks.afterEach(function () {
      document.getElementById("data-authentication").remove();
    });

    test("when skip is enabled but username is missing, shows form", async function (assert) {
      this.siteSettings.auth_skip_create_confirm = true;
      await visit("/");

      assert.dom(".signup-fullpage").exists("it shows the signup page");

      assert
        .dom("#new-account-username")
        .exists("it shows the fields so user can provide username");
    });
  }
);

acceptance(
  "Create Account - external auth with full name required but not from provider",
  function (needs) {
    needs.hooks.beforeEach(function () {
      setupAuthData({ name: "Testuser", name_from_provider: false });
    });
    needs.hooks.afterEach(function () {
      document.getElementById("data-authentication").remove();
    });

    needs.site({ full_name_required_for_signup: true });

    test("when skip is enabled but name is required and not from provider, shows form", async function (assert) {
      this.siteSettings.auth_skip_create_confirm = true;
      await visit("/");

      assert.dom(".signup-fullpage").exists("it shows the signup page");
      assert.dom("#new-account-name").exists("it shows the name field");
    });
  }
);

acceptance(
  "Create Account - external auth with full name required and from provider",
  function (needs) {
    needs.hooks.beforeEach(function () {
      setupAuthData({ name: "John Doe", name_from_provider: true });
    });
    needs.hooks.afterEach(function () {
      document.getElementById("data-authentication").remove();
    });

    needs.site({ full_name_required_for_signup: true });

    test("when skip is enabled and name is from provider, skips form", async function (assert) {
      this.siteSettings.auth_skip_create_confirm = true;
      await visit("/");

      assert.dom(".signup-fullpage").exists("it shows the signup page");
      assert
        .dom("#new-account-username")
        .doesNotExist("it does not show the fields");
    });
  }
);

acceptance("Create account - with associate link", function (needs) {
  needs.hooks.beforeEach(function () {
    setupAuthData({ associate_url: "/associate/abcde" });
  });
  needs.hooks.afterEach(function () {
    document.getElementById("data-authentication").remove();
  });

  test("displays associate link when allowed", async function (assert) {
    await visit("/");

    assert.dom(".signup-fullpage").exists("it shows the signup page");
    assert.dom("#new-account-username").exists("it shows the fields");
    assert
      .dom(".create-account-associate-link")
      .exists("it shows the associate link");
  });
});
