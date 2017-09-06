import { acceptance } from "helpers/qunit-helpers";
acceptance("Admin - Flagged Topics", { loggedIn: true });

QUnit.test("topics with flags", assert => {
  visit("/admin/flags/topics");
  andThen(() => {
    assert.ok(exists('.watched-words-list'));
    assert.ok(!exists('.watched-words-list .watched-word'), "Don't show bad words by default.");
  });
});

