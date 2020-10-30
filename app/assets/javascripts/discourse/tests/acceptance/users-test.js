import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("User Directory", function () {
  test("Visit Page", async (assert) => {
    await visit("/u");
    assert.ok($("body.users-page").length, "has the body class");
    assert.ok(exists(".directory table tr"), "has a list of users");
  });

  test("Visit All Time", async (assert) => {
    await visit("/u?period=all");
    assert.ok(exists(".time-read"), "has time read column");
  });

  test("Visit Without Usernames", async (assert) => {
    await visit("/u?exclude_usernames=system");
    assert.ok($("body.users-page").length, "has the body class");
    assert.ok(exists(".directory table tr"), "has a list of users");
  });

  test("Visit With Group Filter", async (assert) => {
    await visit("/u?group=trust_level_0");
    assert.ok($("body.users-page").length, "has the body class");
    assert.ok(exists(".directory table tr"), "has a list of users");
  });
});
