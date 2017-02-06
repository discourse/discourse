import { acceptance } from "helpers/qunit-helpers";
import PreloadStore from 'preload-store';
import { parsePostData } from "helpers/create-pretender";

acceptance("Password Reset", {
  setup() {
    const response = (object) => {
      return [
        200,
        {"Content-Type": "application/json"},
        object
      ];
    };

    server.get('/users/confirm-email-token/myvalidtoken.json', () => { //eslint-disable-line
      return response({success: "OK"});
    });

    server.put('/users/password-reset/myvalidtoken.json', request => { //eslint-disable-line
      const body = parsePostData(request.requestBody);
      if (body.password === "jonesyAlienSlayer") {
        return response({success: false, errors: {password: ["is the name of your cat"]}});
      } else {
        return response({success: "OK", message: I18n.t('password_reset.success')});
      }
    });
  }
});

test("Password Reset Page", () => {
  PreloadStore.store('password_reset', {is_developer: false});

  visit("/users/password-reset/myvalidtoken");
  andThen(() => {
    ok(exists(".password-reset input"), "shows the input");
  });

  fillIn('.password-reset input', 'perf3ctly5ecur3');
  andThen(() => {
    ok(exists(".password-reset .tip.good"), "input looks good");
  });

  fillIn('.password-reset input', '123');
  andThen(() => {
    ok(exists(".password-reset .tip.bad"), "input is not valid");
    ok(find(".password-reset .tip.bad").html().indexOf(I18n.t('user.password.too_short')) > -1, "password too short");
  });

  fillIn('.password-reset input', 'jonesyAlienSlayer');
  click('.password-reset form button');
  andThen(() => {
    ok(exists(".password-reset .tip.bad"), "input is not valid");
    ok(find(".password-reset .tip.bad").html().indexOf("is the name of your cat") > -1, "server validation error message shows");
  });

  fillIn('.password-reset input', 'perf3ctly5ecur3');
  click('.password-reset form button');
  andThen(() => {
    ok(!exists(".password-reset form"), "form is gone");
  });
});

