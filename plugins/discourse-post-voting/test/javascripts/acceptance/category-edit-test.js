import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function latestCategorySavePayload() {
  const request = pretender.handledRequests.findLast(
    ({ method, requestBody }) => method === "PUT" && requestBody
  );

  return JSON.parse(request.requestBody);
}

acceptance("Category Edit", function (needs) {
  needs.user();
  needs.settings({ post_voting_enabled: true });

  test("Editing the category to create_as_post_voting_default", async function (assert) {
    await visit("/c/bug/edit/settings");
    await formKit()
      .field("custom_fields.create_as_post_voting_default")
      .toggle();

    await click(".admin-changes-banner .btn-primary");

    const payload = latestCategorySavePayload();
    assert.true(payload.custom_fields.create_as_post_voting_default);
  });

  test("Editing the category to only_post_voting_in_this_category", async function (assert) {
    await visit("/c/bug/edit/settings");
    await formKit()
      .field("custom_fields.only_post_voting_in_this_category")
      .toggle();

    await click(".admin-changes-banner .btn-primary");

    const payload = latestCategorySavePayload();
    assert.true(payload.custom_fields.only_post_voting_in_this_category);
  });
});
