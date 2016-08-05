import { acceptance } from "helpers/qunit-helpers";

acceptance("User Directory - Mobile", { mobileView: true });

test("Visit Page", () => {
  visit("/users");
  andThen(() => {
    ok(exists('.directory .user'), "has a list of users");
  });
});
