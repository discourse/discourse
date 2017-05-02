import { acceptance } from "helpers/qunit-helpers";
import PreloadStore from 'preload-store';

acceptance("Account Created");

test("account created", () => {
  visit("/u/account-created");
  PreloadStore.store('accountCreated', {
    message: "Hello World"
  });

  andThen(() => {
    ok(exists('.account-created'));
    equal(find('.account-created').text(), "Hello World", "it displays the message");
  });
});

