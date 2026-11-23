import { tracked } from "@glimmer/tracking";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
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

module(
  "Integration | Component | workflows tags editor with the new select controls",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
      this.puts = [];
      pretender.get(
        "/admin/plugins/discourse-workflows/workflow-tags.json",
        () =>
          response(200, {
            workflow_tags: [{ id: 1, name: "ops", workflow_count: 2 }],
          })
      );
      pretender.put(
        "/admin/plugins/discourse-workflows/workflows/1.json",
        (request) => {
          const body = JSON.parse(request.requestBody);
          this.puts.push(body.workflow.tags);
          return response(200, {
            workflow: { id: 1, tags: body.workflow.tags },
          });
        }
      );
    });

    test("picks and creates tags, saving each change", async function (assert) {
      this.workflow = workflowFor([]);

      await render(
        <template><WorkflowTagsEditor @workflow={{this.workflow}} /></template>
      );
      await click(".workflows-tags-editor__manage");

      const tags = dSelect(".workflows-tags-editor .d-select");
      assert
        .dom(".workflows-tags-editor [role='combobox']")
        .hasAria("label", i18n("discourse_workflows.tags.label"))
        .hasAttribute(
          "placeholder",
          i18n("discourse_workflows.tags.placeholder")
        );

      await tags.open();
      await tags.select("ops");
      await tags.search("urgent");
      await tags.select("urgent");

      assert.deepEqual(this.puts, [["ops"], ["ops", "urgent"]]);
      assert.deepEqual(this.workflow.tags, ["ops", "urgent"]);
    });

    test("holds at most 10 tags", async function (assert) {
      this.workflow = workflowFor([
        "a",
        "b",
        "c",
        "d",
        "e",
        "f",
        "g",
        "h",
        "i",
        "j",
      ]);

      await render(
        <template><WorkflowTagsEditor @workflow={{this.workflow}} /></template>
      );
      await click(".workflows-tags-editor__manage");

      const tags = dSelect(".workflows-tags-editor .d-select");
      await tags.open();
      await click("[role='option'][data-value='ops']");

      assert.deepEqual(this.puts, [], "an eleventh tag isn't added");
    });
  }
);
