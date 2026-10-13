import { tracked } from "@glimmer/tracking";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowVariableDefinitions from "discourse/plugins/discourse-workflows/admin/components/workflows/variable-definitions";

class TestWorkflow {
  @tracked variables;
  @tracked hasUnpublishedChanges;
  @tracked versionId;
  @tracked activeVersionId;

  constructor({
    id,
    variables = [],
    hasUnpublishedChanges = false,
    versionId = "draft-uuid",
    activeVersionId = "published-uuid",
  } = {}) {
    this.id = id;
    this.variables = variables;
    this.hasUnpublishedChanges = hasUnpublishedChanges;
    this.versionId = versionId;
    this.activeVersionId = activeVersionId;
  }

  setProperties(props) {
    Object.assign(this, props);
  }
}

module(
  "Integration | Component | WorkflowVariableDefinitions",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders existing variable definitions", async function (assert) {
      const workflow = new TestWorkflow({
        id: 1,
        variables: [
          {
            id: 10,
            key: "priority",
            label: "Priority",
            variable_type: "string",
          },
        ],
      });

      await render(
        <template>
          <WorkflowVariableDefinitions @workflow={{workflow}} />
        </template>
      );

      assert.dom(".d-table__overview-name").hasText("Priority");
      assert.dom(".workflows-variable-key").hasText("priority");
      assert.dom(".workflows-variables-table__type").hasText("String");
    });

    test("edit navigates to the dedicated edit route", async function (assert) {
      let transitionedTo;
      this.owner.lookup("service:router").transitionTo = (route, ...models) => {
        transitionedTo = { route, models };
      };

      const workflow = new TestWorkflow({
        id: 1,
        variables: [
          {
            id: 10,
            key: "priority",
            label: "Priority",
            variable_type: "string",
          },
        ],
      });

      await render(
        <template>
          <WorkflowVariableDefinitions @workflow={{workflow}} />
        </template>
      );

      await click(".workflows-variables-table__edit");

      assert.deepEqual(transitionedTo, {
        route: "adminPlugins.show.discourse-workflows.show.variables.edit",
        models: [10],
      });
    });

    test("add variable navigates to the dedicated new route", async function (assert) {
      let transitionedTo;
      this.owner.lookup("service:router").transitionTo = (route) => {
        transitionedTo = route;
      };

      const workflow = new TestWorkflow({
        id: 1,
        variables: [
          {
            id: 10,
            key: "priority",
            label: "Priority",
            variable_type: "string",
          },
        ],
      });

      await render(
        <template>
          <WorkflowVariableDefinitions @workflow={{workflow}} />
        </template>
      );

      await click(".workflows-variables__add");

      assert.strictEqual(
        transitionedTo,
        "adminPlugins.show.discourse-workflows.show.variables.new"
      );
    });

    test("empty state CTA navigates to the dedicated new route", async function (assert) {
      let transitionedTo;
      this.owner.lookup("service:router").transitionTo = (route) => {
        transitionedTo = route;
      };

      const workflow = new TestWorkflow({ id: 1, variables: [] });

      await render(
        <template>
          <WorkflowVariableDefinitions @workflow={{workflow}} />
        </template>
      );

      await click(".admin-config-area-empty-list__cta-button");

      assert.strictEqual(
        transitionedTo,
        "adminPlugins.show.discourse-workflows.show.variables.new"
      );
    });
  }
);
