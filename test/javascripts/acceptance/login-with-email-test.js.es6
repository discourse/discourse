import { acceptance } from "helpers/qunit-helpers";

let userFound = false;

acceptance("Login with email", {
  settings: {
    enable_local_logins_via_email: true,
    enable_facebook_logins: true
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

QUnit.test("logging in via email (link)", assert => {
  visit("/");
  click("header .login-button");

  andThen(() => {
    assert.notOk(exists(".login-with-email-link"), 'it displays the link only when field is filled');
    userFound = false;
  });

  fillIn("#login-account-name", "someuser");
  click(".login-with-email-link");

  andThen(() => {
    assert.equal(
      find(".alert-error").html(),
      I18n.t('email_login.complete_username_not_found', { username: 'someuser' }),
      'it should display an error for an invalid username'
    );
  });

  fillIn("#login-account-name", 'someuser@gmail.com');
  click('.login-with-email-link');

  andThen(() => {
    assert.equal(
      find(".alert-error").html(),
      I18n.t('email_login.complete_email_not_found', { email: 'someuser@gmail.com' }),
      'it should display an error for an invalid email'
    );
  });

  fillIn("#login-account-name", 'someuser');

  andThen(() => {
    userFound = true;
  });

  click('.login-with-email-link');

  andThen(() => {
    assert.equal(
      find(".alert-success").html().trim(),
      I18n.t('email_login.complete_username_found', { username: 'someuser' }),
      'it should display a success message for a valid username'
    );
  });

  visit("/");
  click("header .login-button");
  fillIn("#login-account-name", 'someuser@gmail.com');
  click('.login-with-email-link');

  andThen(() => {
    assert.equal(
      find(".alert-success").html().trim(),
      I18n.t('email_login.complete_email_found', { email: 'someuser@gmail.com' }),
      'it should display a success message for a valid email'
    );
  });

  andThen(() => {
    userFound = false;
  });
});

QUnit.test("logging in via email (button)", assert => {
  visit("/");
  click("header .login-button");
  click('.login-with-email-button');

  andThen(() => {
    assert.equal(
      find(".alert-error").html(),
      I18n.t('login.blank_username'),
      'it should display an error for blank username'
    );
  });

  andThen(() => {
    userFound = true;
  });

  fillIn("#login-account-name", 'someuser');
  click('.login-with-email-button');

  andThen(() => {
    assert.equal(
      find(".alert-success").html().trim(),
      I18n.t('email_login.complete_username_found', { username: 'someuser' }),
      'it should display a success message for a valid username'
    );
  });
});
