import { tracked } from "@glimmer/tracking";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import WorkflowTagsEditor from "discourse/plugins/discourse-workflows/admin/components/workflows/tags-editor";

class FakeWorkflow {
  @tracked tags;

  id = 1;

  constructor(tags) {
    this.tags = tags;
  }

  set(key, value) {
    this[key] = value;
  }
}

function workflowFor(tags) {
  return new FakeWorkflow(tags);
}

module("Integration | Component | workflows tags editor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/discourse-workflows/workflow-tags.json", () =>
      response(200, {
        workflow_tags: [{ id: 1, name: "ops", workflow_count: 2 }],
      })
    );
  });

  test("renders the workflow tags as chips", async function (assert) {
    this.workflow = workflowFor(["billing", "ops"]);

    await render(
      <template><WorkflowTagsEditor @workflow={{this.workflow}} /></template>
    );

    assert.dom(".workflows-tags-editor .d-table-badge").exists({ count: 2 });
    assert.dom(".workflows-tags-editor .d-table-badge").hasText("billing");
  });

  test("selecting an existing tag persists it on the workflow", async function (assert) {
    let putBody;
    pretender.put(
      "/admin/plugins/discourse-workflows/workflows/1.json",
      (request) => {
        putBody = JSON.parse(request.requestBody);
        return response(200, {
          workflow: { id: 1, tags: putBody.workflow.tags },
        });
      }
    );

    this.workflow = workflowFor([]);

    await render(
      <template><WorkflowTagsEditor @workflow={{this.workflow}} /></template>
    );

    await click(".workflows-tags-editor__manage");

    const tagSelector = selectKit(".workflows-tags-editor .list-setting");
    await tagSelector.expand();
    await tagSelector.selectRowByValue("ops");

    assert.deepEqual(putBody.workflow.tags, ["ops"]);
    assert.deepEqual(this.workflow.tags, ["ops"]);

    await click(".workflows-tags-editor__done");
    assert.dom(".workflows-tags-editor .d-table-badge").hasText("ops");
  });

  test("creating a new tag sends it in the update", async function (assert) {
    let putBody;
    pretender.put(
      "/admin/plugins/discourse-workflows/workflows/1.json",
      (request) => {
        putBody = JSON.parse(request.requestBody);
        return response(200, { workflow: { id: 1, tags: ["urgent"] } });
      }
    );

    this.workflow = workflowFor([]);

    await render(
      <template><WorkflowTagsEditor @workflow={{this.workflow}} /></template>
    );

    await click(".workflows-tags-editor__manage");

    const tagSelector = selectKit(".workflows-tags-editor .list-setting");
    await tagSelector.expand();
    await tagSelector.fillInFilter("urgent");
    await tagSelector.selectRowByValue("urgent");

    assert.deepEqual(putBody.workflow.tags, ["urgent"]);
    assert.deepEqual(this.workflow.tags, ["urgent"]);
  });

  test("a failed update restores the previous tags", async function (assert) {
    pretender.put("/admin/plugins/discourse-workflows/workflows/1.json", () =>
      response(422, { errors: ["too many tags"] })
    );

    this.workflow = workflowFor(["billing"]);

    await render(
      <template><WorkflowTagsEditor @workflow={{this.workflow}} /></template>
    );

    await click(".workflows-tags-editor__manage");

    const tagSelector = selectKit(".workflows-tags-editor .list-setting");
    await tagSelector.expand();
    await tagSelector.selectRowByValue("ops");

    assert.deepEqual(
      this.workflow.tags,
      ["billing"],
      "failed saves roll back to the last persisted tags"
    );
  });
});
