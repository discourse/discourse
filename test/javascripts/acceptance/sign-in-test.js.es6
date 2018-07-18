import { acceptance } from "helpers/qunit-helpers";
acceptance("Signing In");

QUnit.test("sign in", assert => {
  visit("/");
  click("header .login-button");
  andThen(() => {
    assert.ok(exists(".login-modal"), "it shows the login modal");
  });

  // Test invalid password first
  fillIn("#login-account-name", "eviltrout");
  fillIn("#login-account-password", "incorrect");
  click(".modal-footer .btn-primary");
  andThen(() => {
    assert.ok(exists("#modal-alert:visible"), "it displays the login error");
    assert.not(
      exists(".modal-footer .btn-primary:disabled"),
      "enables the login button"
    );
  });

  // Use the correct password
  fillIn("#login-account-password", "correct");
  click(".modal-footer .btn-primary");
  andThen(() => {
    assert.ok(
      exists(".modal-footer .btn-primary:disabled"),
      "disables the login button"
    );
  });
});

QUnit.test("sign in - not activated", assert => {
  visit("/");
  andThen(() => {
    click("header .login-button");
    andThen(() => {
      assert.ok(exists(".login-modal"), "it shows the login modal");
    });

    fillIn("#login-account-name", "eviltrout");
    fillIn("#login-account-password", "not-activated");
    click(".modal-footer .btn-primary");
    andThen(() => {
      assert.equal(
        find(".modal-body b").text(),
        "<small>eviltrout@example.com</small>"
      );
      assert.ok(!exists(".modal-body small"), "it escapes the email address");
    });

    click(".modal-footer button.resend");
    andThen(() => {
      assert.equal(
        find(".modal-body b").text(),
        "<small>current@example.com</small>"
      );
      assert.ok(!exists(".modal-body small"), "it escapes the email address");
    });
  });
});

QUnit.test("sign in - not activated - edit email", assert => {
  visit("/");
  andThen(() => {
    click("header .login-button");
    andThen(() => {
      assert.ok(exists(".login-modal"), "it shows the login modal");
    });

    fillIn("#login-account-name", "eviltrout");
    fillIn("#login-account-password", "not-activated-edit");
    click(".modal-footer .btn-primary");
    click(".modal-footer button.edit-email");
    andThen(() => {
      assert.equal(find(".activate-new-email").val(), "current@example.com");
      assert.equal(
        find(".modal-footer .btn-primary:disabled").length,
        1,
        "must change email"
      );
    });
    fillIn(".activate-new-email", "different@example.com");
    andThen(() => {
      assert.equal(find(".modal-footer .btn-primary:disabled").length, 0);
    });
    click(".modal-footer .btn-primary");
    andThen(() => {
      assert.equal(find(".modal-body b").text(), "different@example.com");
    });
  });
});

QUnit.test("second factor", assert => {
  visit("/");
  click("header .login-button");

  andThen(() => {
    assert.ok(exists(".login-modal"), "it shows the login modal");
  });

  fillIn("#login-account-name", "eviltrout");
  fillIn("#login-account-password", "need-second-factor");
  click(".modal-footer .btn-primary");

  andThen(() => {
    assert.not(exists("#modal-alert:visible"), "it hides the login error");
    assert.not(
      exists("#credentials:visible"),
      "it hides the username and password prompt"
    );
    assert.ok(
      exists("#second-factor:visible"),
      "it displays the second factor prompt"
    );
    assert.not(
      exists(".modal-footer .btn-primary:disabled"),
      "enables the login button"
    );
  });

  fillIn("#login-second-factor", "123456");
  click(".modal-footer .btn-primary");

  andThen(() => {
    assert.ok(
      exists(".modal-footer .btn-primary:disabled"),
      "disables the login button"
    );
  });
});

QUnit.test("create account", assert => {
  visit("/");
  click("header .sign-up-button");

  andThen(() => {
    assert.ok(exists(".create-account"), "it shows the create account modal");
    assert.ok(
      exists(".modal-footer .btn-primary:disabled"),
      "create account is disabled at first"
    );
  });

  fillIn("#new-account-name", "Dr. Good Tuna");
  fillIn("#new-account-password", "cool password bro");

  // Check username
  fillIn("#new-account-email", "good.tuna@test.com");
  fillIn("#new-account-username", "taken");
  andThen(() => {
    assert.ok(
      exists("#username-validation.bad"),
      "the username validation is bad"
    );
    assert.ok(
      exists(".modal-footer .btn-primary:disabled"),
      "create account is still disabled"
    );
  });

  fillIn("#new-account-username", "goodtuna");
  andThen(() => {
    assert.ok(
      exists("#username-validation.good"),
      "the username validation is good"
    );
    assert.not(
      exists(".modal-footer .btn-primary:disabled"),
      "create account is enabled"
    );
  });

  click(".modal-footer .btn-primary");
  andThen(() => {
    assert.ok(
      exists(".modal-footer .btn-primary:disabled"),
      "create account is disabled"
    );
  });
});

QUnit.test("second factor backup - valid token", assert => {
  visit("/");
  click("header .login-button");
  fillIn("#login-account-name", "eviltrout");
  fillIn("#login-account-password", "need-second-factor");
  click(".modal-footer .btn-primary");
  click(".login-modal .toggle-second-factor-method");
  fillIn("#login-second-factor", "123456");
  click(".modal-footer .btn-primary");

  andThen(() => {
    assert.ok(
      exists(".modal-footer .btn-primary:disabled"),
      "it closes the modal when the code is valid"
    );
  });
});

QUnit.test("second factor backup - invalid token", assert => {
  visit("/");
  click("header .login-button");
  fillIn("#login-account-name", "eviltrout");
  fillIn("#login-account-password", "need-second-factor");
  click(".modal-footer .btn-primary");
  click(".login-modal .toggle-second-factor-method");
  fillIn("#login-second-factor", "something");
  click(".modal-footer .btn-primary");

  andThen(() => {
    assert.ok(
      exists("#modal-alert:visible"),
      "it shows an error when the code is invalid"
    );
  });
});
