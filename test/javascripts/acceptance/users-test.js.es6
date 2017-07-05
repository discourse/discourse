import { acceptance } from "helpers/qunit-helpers";
acceptance("User Directory");

QUnit.test("Visit Page", assert => {
  visit("/users");
  andThen(() => {
    assert.ok($('body.users-page').length, "has the body class");
    assert.ok(exists('.directory table tr'), "has a list of users");
  });
});

QUnit.test("Visit All Time", assert => {
  visit("/users?period=all");
  andThen(() => {
    assert.ok(exists('.time-read'), "has time read column");
  });
});