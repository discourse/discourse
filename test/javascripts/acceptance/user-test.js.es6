import { acceptance } from "helpers/qunit-helpers";
import { hasStream } from 'acceptance/user-anonymous-test';

acceptance("User", {loggedIn: true});

test("Pending", () => {
  visit("/users/eviltrout/activity/pending");
  hasStream();
});

test("Root URL - Viewing Self", () => {
  visit("/users/eviltrout");
  andThen(() => {
    equal(currentPath(), 'user.summary', "it defaults to summary");
  });
});

