import { trustHTML } from "@ember/template";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import AdminAssistantWorkflowPreview from "discourse/plugins/discourse-workflows/discourse/components/admin-assistant/workflow-preview";
import { decorateWorkflowPreview } from "discourse/plugins/discourse-workflows/discourse/initializers/assistant-workflow-preview";
import {
  extractWorkflowPreview,
  layoutWorkflowPreview,
} from "discourse/plugins/discourse-workflows/discourse/lib/admin-assistant/workflow-preview";

const APPROVAL_TITLE = "Save this workflow as an unpublished draft?";
const PREVIEW_KIND = "discourse_admin_assistant_workflow_preview_v1";

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function cookedPreview(configuration, kind = PREVIEW_KIND) {
  return `<pre><code class="lang-admin-assistant-workflow">${escapeHtml(JSON.stringify({ kind, configuration }))}</code></pre>`;
}

function addNode(clientId, name, type = "action:log") {
  return {
    op: "add_node",
    client_id: clientId,
    node: { name, parameters: {}, type },
  };
}

function approvalMessage(
  id,
  configuration,
  title = APPROVAL_TITLE,
  kind = PREVIEW_KIND
) {
  return {
    id,
    blocks: [{ type: "confirmation", title }],
    cooked: cookedPreview(configuration, kind),
  };
}

module(
  "Discourse Workflows | Admin Assistant | Workflow preview",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders escaped nodes and directed branches from the exact configuration", async function (assert) {
      const maliciousName = '<img src=x onerror="alert(1)">';
      this.message = approvalMessage(42, {
        name: '<script>alert("workflow")</script>',
        operations: [
          addNode("start", maliciousName, "trigger:manual"),
          addNode("condition", "Check trust", "logic:condition"),
          addNode("accepted", "Send welcome"),
          addNode("rejected", "Record rejection"),
          { op: "add_connection", from: "start", to: "condition" },
          {
            op: "add_connection",
            from: "condition",
            to: "accepted",
            output_index: 0,
          },
          {
            op: "add_connection",
            from: "condition",
            to: "rejected",
            output_index: 1,
          },
        ],
      });
      const layout = layoutWorkflowPreview(
        extractWorkflowPreview(this.message.cooked)
      );

      assert.deepEqual(
        layout.nodes.map(({ id, x, y }) => ({ id, x, y })),
        [
          { id: "node-0", x: 20, y: 20 },
          { id: "node-1", x: 228, y: 20 },
          { id: "node-2", x: 436, y: 20 },
          { id: "node-3", x: 436, y: 144 },
        ],
        "places both branch targets in a stable lane"
      );
      assert.deepEqual(
        layout.connections.map(({ from, outputIndex, to }) => ({
          from,
          outputIndex,
          to,
        })),
        [
          { from: "node-0", outputIndex: 0, to: "node-1" },
          { from: "node-1", outputIndex: 0, to: "node-2" },
          { from: "node-1", outputIndex: 1, to: "node-3" },
        ],
        "connects the expected nodes"
      );

      await render(
        <template>
          <AdminAssistantWorkflowPreview @message={{this.message}} />
        </template>
      );

      assert
        .dom(".assistant-workflow-preview__heading")
        .hasText('<script>alert("workflow")</script>');
      assert.dom(".assistant-workflow-preview__node").exists({ count: 4 });
      assert
        .dom(".assistant-workflow-preview__connection")
        .exists({ count: 3 });
      assert
        .dom('[data-node-type="trigger:manual"] strong')
        .hasText(maliciousName);
      assert.dom(".assistant-workflow-preview img").doesNotExist();
      assert.dom(".assistant-workflow-preview script").doesNotExist();
      assert
        .dom('[data-output-index="1"]')
        .hasText("Branch 2", "labels the second output branch");
      assert
        .dom(".assistant-workflow-preview__node .sr-only")
        .includesText("Connects to Check trust");
      assert
        .dom('[data-node-type="logic:condition"] .sr-only')
        .includesText("Branch 2: Record rejection");
      assert
        .dom(".assistant-workflow-preview__badge")
        .hasText("Read-only preview");
    });

    test("keeps nodes and SVG connections aligned in RTL", async function (assert) {
      this.message = approvalMessage(110, {
        name: "RTL workflow",
        operations: [
          addNode("start", "Start", "trigger:manual"),
          addNode("end", "End"),
          { op: "add_connection", from: "start", to: "end" },
        ],
      });
      await render(
        <template>
          <div dir="rtl">
            <AdminAssistantWorkflowPreview @message={{this.message}} />
          </div>
        </template>
      );
      const nodes = this.element.querySelectorAll(
        ".assistant-workflow-preview__node"
      );
      const connection = this.element.querySelector(
        ".assistant-workflow-preview__connection"
      );
      const start = connection
        .getPointAtLength(0)
        .matrixTransform(connection.getScreenCTM());
      const end = connection
        .getPointAtLength(connection.getTotalLength())
        .matrixTransform(connection.getScreenCTM());
      assert.true(
        Math.abs(start.x - nodes[0].getBoundingClientRect().right) < 1,
        "connection starts at the source node"
      );
      assert.true(
        Math.abs(end.x - nodes[1].getBoundingClientRect().left) < 1,
        "connection ends at the target node"
      );
      assert.strictEqual(
        getComputedStyle(nodes[0]).direction,
        "rtl",
        "node text keeps the page direction"
      );
    });

    test("shows script-check warnings and preserves errors in exact configuration", async function (assert) {
      this.message = approvalMessage(111, {
        name: "Code workflow",
        operations: [addNode("code", "Process items", "action:code")],
        script_validations: [
          {
            operation_index: 0,
            node_name: "Process items",
            valid: false,
            errors: ["<img src=x onerror=alert(1)> invalid script"],
          },
        ],
      });
      await render(
        <template>
          <AdminAssistantWorkflowPreview @message={{this.message}} />
        </template>
      );
      assert.dom(".assistant-workflow-preview__warning").exists();
      assert
        .dom(".assistant-workflow-preview__details code")
        .includesText("invalid script");
      assert.dom(".assistant-workflow-preview img").doesNotExist();
    });

    test("does not warn for successful script checks", async function (assert) {
      this.message = approvalMessage(112, {
        name: "Code workflow",
        operations: [addNode("code", "Process items", "action:code")],
        script_validations: [{ valid: true, errors: [] }],
      });
      await render(
        <template>
          <AdminAssistantWorkflowPreview @message={{this.message}} />
        </template>
      );
      assert.dom(".assistant-workflow-preview__warning").doesNotExist();
    });

    test("lays out cycles deterministically and labels them", async function (assert) {
      const configuration = {
        name: "Retry loop",
        operations: [
          addNode("start", "Start", "trigger:manual"),
          addNode("retry", "Retry"),
          { op: "add_connection", from: "start", to: "retry" },
          { op: "add_connection", from: "retry", to: "start" },
        ],
      };
      const preview = extractWorkflowPreview(cookedPreview(configuration));
      const layout = layoutWorkflowPreview(preview);

      assert.deepEqual(
        layout.nodes.map(({ id, x, y }) => ({ id, x, y })),
        [
          { id: "node-0", x: 20, y: 20 },
          { id: "node-1", x: 20, y: 144 },
        ],
        "keeps a strongly connected component together"
      );
      assert.true(layout.hasCycle);
      assert.true(
        layout.connections.every((connection) =>
          connection.path.includes(" C ")
        ),
        "draws both directed cycle connections"
      );

      this.message = approvalMessage(43, configuration);
      await render(
        <template>
          <AdminAssistantWorkflowPreview @message={{this.message}} />
        </template>
      );

      assert
        .dom(".assistant-workflow-preview__connection")
        .exists({ count: 2 });
      assert
        .dom(".assistant-workflow-preview__footer")
        .includesText("Includes a cycle");
    });

    test("simulates rename, removal, reconnection, and self-loops", function (assert) {
      const preview = extractWorkflowPreview(
        cookedPreview({
          name: "Mutated graph",
          operations: [
            addNode("start", "Start", "trigger:manual"),
            addNode("temporary", "Temporary"),
            addNode("kept", "Original"),
            { op: "add_connection", from: "start", to: "temporary" },
            { op: "remove_node", client_id: "temporary" },
            { op: "rename_node", client_id: "kept", name: "Renamed" },
            addNode("after", "After removal"),
            { op: "add_connection", from: "start", to: "after" },
            { op: "remove_connection", from: "start", to: "after" },
            { op: "add_connection", from: "start", to: "kept" },
            { op: "add_connection", from: "kept", to: "kept" },
            { op: "add_connection", from: "kept", to: "after" },
          ],
        })
      );
      const layout = layoutWorkflowPreview(preview);

      assert.deepEqual(
        preview.nodes.map(({ id, name }) => ({ id, name })),
        [
          { id: "node-0", name: "Start" },
          { id: "node-2", name: "Renamed" },
          { id: "node-3", name: "After removal" },
        ]
      );
      assert.deepEqual(
        preview.connections.map(({ from, to }) => ({ from, to })),
        [
          { from: "node-0", to: "node-2" },
          { from: "node-2", to: "node-2" },
          { from: "node-2", to: "node-3" },
        ]
      );
      assert.true(layout.hasCycle, "recognizes a self-loop as a cycle");
    });

    test("falls back honestly for unsupported or oversized exact drafts", async function (assert) {
      this.message = approvalMessage(44, {
        name: "Unsupported graph",
        operations: [{ op: "future_operation" }],
      });

      await render(
        <template>
          <AdminAssistantWorkflowPreview @message={{this.message}} />
        </template>
      );

      assert.dom(".assistant-workflow-preview__node").doesNotExist();
      assert
        .dom(".assistant-workflow-preview__fallback")
        .includesText("Review the exact configuration before approving");

      this.set(
        "message",
        approvalMessage(45, {
          name: "Large graph",
          operations: Array.from({ length: 25 }, (_, index) =>
            addNode(`node-${index}`, `Node ${index}`)
          ),
        })
      );

      await settled();
      assert.dom(".assistant-workflow-preview__node").doesNotExist();
      assert.dom(".assistant-workflow-preview__fallback").exists();
    });

    test("does not render for non-workflow confirmation cards", async function (assert) {
      this.message = approvalMessage(
        46,
        { name: "Spoof", operations: [addNode("start", "Start")] },
        "Another approval",
        "another_tool_preview_v1"
      );

      await render(
        <template>
          <AdminAssistantWorkflowPreview @message={{this.message}} />
        </template>
      );

      assert.dom(".assistant-workflow-preview").doesNotExist();
    });

    test("renders the preview in the confirmation body before the controls", async function (assert) {
      this.message = approvalMessage(99, {
        name: "Manual workflow",
        operations: [addNode("manual", "Manual trigger", "trigger:manual")],
      });
      this.cooked = trustHTML(this.message.cooked);
      this.decorate = (element, helper) =>
        decorateWorkflowPreview(element, helper, this.message);

      await render(
        <template>
          <section class="chat-confirmation">
            <div class="chat-confirmation__description">
              <DDecoratedHtml
                @decorate={{this.decorate}}
                @html={{this.cooked}}
              />
            </div>
            <div class="chat-confirmation__footer">Approve or reject</div>
          </section>
        </template>
      );

      assert.dom(".assistant-workflow-preview").exists({ count: 1 });
      const preview = this.element.querySelector(".assistant-workflow-preview");
      const controls = this.element.querySelector(".chat-confirmation__footer");
      assert.strictEqual(
        preview.compareDocumentPosition(controls),
        Node.DOCUMENT_POSITION_FOLLOWING
      );
      assert
        .dom(".assistant-workflow-preview__footer")
        .includesText("1 node · 0 connections");
      assert
        .dom(".assistant-workflow-preview__footer")
        .includesText("Exact configuration");
      assert
        .dom(".assistant-workflow-preview__details")
        .doesNotHaveAttribute("open");
      await click(".assistant-workflow-preview__footer");
      assert.dom(".assistant-workflow-preview__details").hasAttribute("open");
      assert
        .dom(".assistant-workflow-preview__details code")
        .includesText('"Manual workflow"');
    });

    test("leaves ordinary code and non-confirmation messages unchanged", function (assert) {
      const element = document.createElement("div");
      element.innerHTML = cookedPreview({ name: "Manual", operations: [] });
      const original = element.innerHTML;
      const helper = {
        renderGlimmer() {
          assert.true(false, "must not mount outside a confirmation");
        },
      };
      decorateWorkflowPreview(element, helper, {
        blocks: [],
        cooked: original,
      });
      assert.strictEqual(element.innerHTML, original);

      element.innerHTML = "<pre><code>ordinary code</code></pre>";
      const ordinary = element.innerHTML;
      decorateWorkflowPreview(element, helper, {
        blocks: [{ type: "confirmation" }],
      });
      assert.strictEqual(element.innerHTML, ordinary);

      element.innerHTML = original;
      decorateWorkflowPreview(
        element,
        {},
        { blocks: [{ type: "confirmation" }] }
      );
      assert.strictEqual(
        element.innerHTML,
        original,
        "preserves readable configuration without mounting support"
      );
    });

    test("does not replace another payload in a confirmation title or error", function (assert) {
      const message = approvalMessage(101, {
        name: "Approved configuration",
        operations: [addNode("manual", "Manual", "trigger:manual")],
      });
      const element = document.createElement("div");
      element.innerHTML = cookedPreview({
        name: "Different configuration",
        operations: [],
      });
      const original = element.innerHTML;
      decorateWorkflowPreview(
        element,
        {
          renderGlimmer() {
            assert.true(false, "must not mount a different payload");
          },
        },
        message
      );
      assert.strictEqual(element.innerHTML, original);
    });
  }
);
