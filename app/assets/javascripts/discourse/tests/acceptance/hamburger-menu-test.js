import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Opening the hamburger menu with some reviewables", {
  loggedIn: true,
  pretend: (server, helper) => {
    server.get("/review/count.json", () => helper.response({ count: 3 }));
  },
});

QUnit.test("As a staff member", async (assert) => {
  updateCurrentUser({ moderator: true, admin: false });

  await visit("/");
  await click(".hamburger-dropdown");

  assert.equal(find(".review .badge-notification.reviewables").text(), "3");
});
