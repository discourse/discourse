import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic Discovery - Mobile", { mobileView: true });

QUnit.test("Visit Discovery Pages", async assert => {
  await visit("/");
  assert.ok(exists(".topic-list"), "The list of topics was rendered");
  assert.ok(exists(".topic-list .topic-list-item"), "has topics");

  await visit("/categories");
  assert.ok(exists(".category"), "has a list of categories");
});
