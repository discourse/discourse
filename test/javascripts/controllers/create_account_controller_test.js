module("controller:create-account");

test('basicUsernameValidation', function() {
  var testInvalidUsername = function(username, expectedReason) {
    var controller = controllerFor('create-account');
    controller.set('accountUsername', username);
    equal(controller.get('basicUsernameValidation.failed'), true, 'username should be invalid: ' + username);
    equal(controller.get('basicUsernameValidation.reason'), expectedReason, 'username validation reason: ' + username + ', ' + expectedReason);
  };

  testInvalidUsername('', undefined);
  testInvalidUsername('x', I18n.t('user.username.too_short'));
  testInvalidUsername('123456789012345678901', I18n.t('user.username.too_long'));

  var controller = controllerFor('create-account');
  controller.set('accountUsername',   'porkchops');
  controller.set('prefilledUsername', 'porkchops');
  equal(controller.get('basicUsernameValidation.ok'), true, 'Prefilled username is valid');
  equal(controller.get('basicUsernameValidation.reason'), I18n.t('user.username.prefilled'), 'Prefilled username is valid');
});
