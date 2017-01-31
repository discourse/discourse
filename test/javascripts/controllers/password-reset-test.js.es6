moduleFor("controller:password-reset");

test("passwordValidation", function() {
  const PasswordResetController = this.subject();

  PasswordResetController.setProperties({
    model: {is_developer: false, token: "123456abcdef"}
  });

  PasswordResetController.set('accountPassword', "perf3ctly5ecur3");
  equal(PasswordResetController.get('passwordValidation.ok'), true, 'password is ok');
  equal(PasswordResetController.get('passwordValidation.reason'), I18n.t('user.password.ok'), 'password is valid');

  var testInvalidPassword = function(password, expectedReason) {
    PasswordResetController.set('accountPassword', password);
    equal(PasswordResetController.get('passwordValidation.failed'), true, 'password should be invalid: ' + password);
    equal(PasswordResetController.get('passwordValidation.reason'), expectedReason, 'password validation reason: ' + password + ', ' + expectedReason);
  };

  testInvalidPassword('123', I18n.t('user.password.too_short'));

  // a password was submitted and error returned from server
  PasswordResetController.get('rejectedPasswords').pushObject('serverRejectsThis');
  PasswordResetController.get('rejectedPasswordsMessages').set('serverRejectsThis', "Validation msg from server");
  testInvalidPassword('serverRejectsThis', "Validation msg from server");

  PasswordResetController.set('accountPassword', "perf3ctly5ecure2");
  equal(PasswordResetController.get('passwordValidation.ok'), true, 'password is ok');
  equal(PasswordResetController.get('passwordValidation.reason'), I18n.t('user.password.ok'), 'password is valid');

  testInvalidPassword('serverRejectsThis', "Validation msg from server"); // try bad one again
});
