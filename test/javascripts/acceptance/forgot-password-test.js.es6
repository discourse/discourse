import { acceptance } from "helpers/qunit-helpers";

let userFound = false;

acceptance("Forgot password", {
  settings: {
    enable_local_logins_via_email: true
  },
  beforeEach() {
    const response = object => {
      return [
        200,
        { "Content-Type": "application/json" },
        object
      ];
    };

    server.post('/u/email-login', () => { // eslint-disable-line no-undef
      return response({ "user_found": userFound });
    });
  }
});

QUnit.test("logging in via email", assert => {
  visit("/");
  click("header .login-button");

  andThen(() => {
    assert.ok(exists('.login-modal'), "it shows the login modal");
  });

  click('#forgot-password-link');

  fillIn("#username-or-email", 'someuser');
  click('.email-login');

  andThen(() => {
    assert.equal(
      find(".alert-error").html(),
      I18n.t('email_login.complete_username_not_found', { username: 'someuser' }),
      'it should display the right error message'
    );
  });

  fillIn("#username-or-email", 'someuser@gmail.com');
  click('.email-login');

  andThen(() => {
    assert.equal(
      find(".alert-error").html(),
      I18n.t('email_login.complete_email_not_found', { email: 'someuser@gmail.com' }),
      'it should display the right error message'
    );
  });

  fillIn("#username-or-email", 'someuser');

  andThen(() => {
    userFound = true;
  });

  click('.email-login');

  andThen(() => {
    assert.equal(
      find(".modal-body").html().trim(),
      I18n.t('email_login.complete_username_found', { username: 'someuser' }),
      'it should display the right message'
    );
  });

  visit("/");
  click("header .login-button");

  andThen(() => {
    assert.ok(exists('.login-modal'), "it shows the login modal");
  });

  click('#forgot-password-link');
  fillIn("#username-or-email", 'someuser@gmail.com');
  click('.email-login');

  andThen(() => {
    assert.equal(
      find(".modal-body").html().trim(),
      I18n.t('email_login.complete_email_found', { email: 'someuser@gmail.com' }),
      'it should display the right message'
    );
  });
});
