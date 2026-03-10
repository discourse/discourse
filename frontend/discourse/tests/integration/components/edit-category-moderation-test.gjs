import { render, select } from "@ember/test-helpers";
import { module, test } from "qunit";
import EditCategoryModeration from "discourse/admin/components/edit-category-moderation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | EditCategoryModeration", function (hooks) {
  setupRenderingTest(hooks);

  test("renders topic and reply approval type dropdowns", async function (assert) {
    await render(<template><EditCategoryModeration /></template>);

    assert.dom(".topic-approval-type select").exists();
    assert.dom(".reply-approval-type select").exists();
  });

  test("topic approval dropdown has 4 options", async function (assert) {
    await render(<template><EditCategoryModeration /></template>);

    assert.dom(".topic-approval-type select option").exists({ count: 4 });
  });

  test("shows GroupChooser when topic_approval_type is except_groups", async function (assert) {
    await render(<template><EditCategoryModeration /></template>);
    await select(".topic-approval-type select", "except_groups");

    assert.dom(".topic-approval-groups .group-chooser").exists();
  });

  test("shows GroupChooser when topic_approval_type is only_groups", async function (assert) {
    await render(<template><EditCategoryModeration /></template>);
    await select(".topic-approval-type select", "only_groups");

    assert.dom(".topic-approval-groups .group-chooser").exists();
  });

  test("hides GroupChooser when topic_approval_type is none or all", async function (assert) {
    await render(<template><EditCategoryModeration /></template>);

    await select(".topic-approval-type select", "none");
    assert.dom(".topic-approval-groups .group-chooser").doesNotExist();

    await select(".topic-approval-type select", "all");
    assert.dom(".topic-approval-groups .group-chooser").doesNotExist();
  });

  test("shows validation error when groups required but none selected", async function (assert) {
    await render(<template><EditCategoryModeration /></template>);
    await select(".topic-approval-type select", "except_groups");

    assert.dom(".topic-approval-groups .form-kit__errors").exists();
  });
});
