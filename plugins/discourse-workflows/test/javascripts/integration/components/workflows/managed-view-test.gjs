import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ManagedWorkflowView from "discourse/plugins/discourse-workflows/admin/components/workflows/managed-view";

module("Integration | Component | ManagedWorkflowView", function (hooks) {
  setupRenderingTest(hooks);

  test("shows a read-only definition and opens an independent duplicate for editing", async function (assert) {
    this.workflow = {
      id: "42",
      managed_by: {
        name: "Example integration",
        configuration_name: "Community members",
        url: "/admin/plugins/example/configurations",
      },
      nodes: [
        {
          id: "trigger",
          name: "User created",
          type: "trigger:user_created",
          parameters: {},
        },
        {
          id: "request",
          name: "HTTP request",
          type: "action:http_request",
          parameters: { method: "POST", dry_run: true },
        },
      ],
    };
    const transition = sinon.stub(
      this.owner.lookup("service:router"),
      "transitionTo"
    );
    pretender.post(
      "/admin/plugins/discourse-workflows/workflows/42/duplicate.json",
      () => response(201, { workflow: { id: "43" } })
    );
    await render(
      <template><ManagedWorkflowView @workflow={{this.workflow}} /></template>
    );
    assert
      .dom(".managed-workflow-view")
      .includesText("Managed by Example integration", "explains ownership");
    assert
      .dom("[data-test-managed-node]")
      .exists({ count: 2 }, "shows both connected steps");
    assert
      .dom(".managed-workflow-view input")
      .doesNotExist("offers no definition inputs");
    assert
      .dom(".managed-workflow-view a")
      .hasAttribute(
        "href",
        "/admin/plugins/example/configurations",
        "links to the owner configuration"
      );
    await click("[data-test-duplicate-managed-workflow]");
    assert.true(
      transition.calledWith("adminPlugins.show.discourse-workflows.show", "43"),
      "opens the duplicate in the normal editor"
    );
    transition.restore();
  });
});
