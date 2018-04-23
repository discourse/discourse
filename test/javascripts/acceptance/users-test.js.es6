import { acceptance } from "helpers/qunit-helpers";
acceptance("User Directory");

QUnit.test("Visit Page", async assert => {
  await visit("/users");
  assert.ok($('body.users-page').length, "has the body class");
  assert.ok(exists('.directory table tr'), "has a list of users");
});

QUnit.test("Visit All Time", async assert => {
  await visit("/users?period=all");
  assert.ok(exists('.time-read'), "has time read column");
});
