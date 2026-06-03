import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import OutputContext from "discourse/plugins/discourse-workflows/admin/components/workflows/context/output";
import WorkflowEditorSession from "discourse/plugins/discourse-workflows/admin/lib/workflows/editor-session";

module(
  "Integration | Component | Workflows | Context | Output",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.session = new WorkflowEditorSession({ lastExecutionRunData: {} });
    });

    hooks.afterEach(function () {
      this.owner.lookup("service:workflows-node-types").clear();
    });

    test("renders output fields from execution run data", async function (assert) {
      const node = {
        clientId: "n1",
        name: "Sample",
        type: "action:http_request",
        typeVersion: "1.0",
        configuration: {},
      };
      const nodes = [node];
      this.session.lastExecutionRunData = {
        Sample: [
          {
            status: "success",
            outputs: [
              {
                index: 0,
                items: [
                  { json: { body: { ok: true }, status: 200 } },
                  { json: { body: { ok: false }, status: 500 } },
                ],
                item_count: 2,
              },
            ],
          },
        ],
      };

      await render(
        <template>
          <OutputContext
            @node={{node}}
            @nodes={{nodes}}
            @connections={{(Array)}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      assert.dom(".workflows-context-panel__title-meta").hasText("2 items");
      assert
        .dom(".workflows-context-panel__hint")
        .hasText(
          "Tip Now that you have output data for this node, you can pin it and use it when executing this trigger manually with the green play button."
        );
      assert.dom(".workflows-context-panel__item-title").doesNotExist();
      const keys = [
        ...this.element.querySelectorAll(".workflows-schema-field__key-title"),
      ].map((el) => el.textContent.trim());
      assert.deepEqual(keys, ["body", "status"]);
    });

    test("asks the user to run the workflow when no execution output is available", async function (assert) {
      const node = {
        clientId: "n1",
        name: "Sample",
        type: "action:http_request",
        typeVersion: "1.0",
        configuration: {},
      };

      await render(
        <template>
          <OutputContext
            @node={{node}}
            @nodes={{Array node}}
            @connections={{(Array)}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      assert
        .dom(".workflows-context-panel__empty-state-title")
        .hasText("No output yet");
      assert.dom(".workflows-context-panel__hint").doesNotExist();
      assert
        .dom(".workflows-context-panel__empty-state-btn")
        .hasText(/Add sample data/);
    });

    test("does not show the pin tip when output data is already pinned", async function (assert) {
      const node = {
        clientId: "n1",
        name: "Sample",
        type: "action:http_request",
        typeVersion: "1.0",
        configuration: {},
      };
      const session = new WorkflowEditorSession({
        lastExecutionRunData: {
          Sample: [
            {
              status: "success",
              outputs: [
                {
                  index: 0,
                  items: [{ json: { body: { ok: true }, status: 200 } }],
                  item_count: 1,
                },
              ],
            },
          ],
        },
        pinData: {
          Sample: [{ json: { body: { pinned: true }, status: 200 } }],
        },
      });

      await render(
        <template>
          <OutputContext
            @node={{node}}
            @nodes={{Array node}}
            @connections={{(Array)}}
            @nodeTypes={{(Array)}}
            @session={{session}}
          />
        </template>
      );

      assert.dom(".workflows-context-panel__pin-banner").exists();
      assert.dom(".workflows-context-panel__hint").doesNotExist();
    });

    test("shows an empty output state when the node executed with zero items", async function (assert) {
      const node = {
        clientId: "n1",
        name: "Sample",
        type: "action:log",
        typeVersion: "1.0",
        configuration: {},
      };
      this.session.lastExecutionRunData = {
        Sample: [
          {
            status: "success",
            outputs: [{ index: 0, items: [], item_count: 0 }],
          },
        ],
      };

      await render(
        <template>
          <OutputContext
            @node={{node}}
            @nodes={{Array node}}
            @connections={{(Array)}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      assert.dom(".workflows-context-panel__title-meta").doesNotExist();
      assert.dom(".workflows-context-panel__empty").hasText("No output data");
    });

    test("shows item count and field-empty state for real empty output items", async function (assert) {
      const node = {
        clientId: "n1",
        name: "Sample",
        type: "action:http_request",
        typeVersion: "1.0",
        configuration: {},
      };
      this.session.lastExecutionRunData = {
        Sample: [
          {
            status: "success",
            outputs: [{ index: 0, items: [{ json: {} }], item_count: 1 }],
          },
        ],
      };

      await render(
        <template>
          <OutputContext
            @node={{node}}
            @nodes={{Array node}}
            @connections={{(Array)}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      assert.dom(".workflows-context-panel__title-meta").hasText("1 item");
      assert.dom(".workflows-context-panel__empty").hasText("No output fields");
    });

    test("does not show stale fields after a later zero-item output", async function (assert) {
      const node = {
        clientId: "n1",
        name: "Sample",
        type: "action:log",
        typeVersion: "1.0",
        configuration: {},
      };
      this.session.lastExecutionRunData = {
        Sample: [
          {
            status: "success",
            outputs: [
              { index: 0, items: [{ json: { stale: true } }], item_count: 1 },
            ],
          },
          {
            status: "success",
            outputs: [{ index: 0, items: [], item_count: 0 }],
          },
        ],
      };

      await render(
        <template>
          <OutputContext
            @node={{node}}
            @nodes={{Array node}}
            @connections={{(Array)}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      assert.dom(".workflows-schema-field__key-title").doesNotExist();
      assert.dom(".workflows-context-panel__empty").hasText("No output data");
    });

    test("merges fields across output items without rendering item rows", async function (assert) {
      const node = {
        clientId: "n1",
        name: "Sample",
        type: "action:http_request",
        typeVersion: "1.0",
        configuration: {},
      };
      this.session.lastExecutionRunData = {
        Sample: [
          {
            status: "success",
            outputs: [
              {
                index: 0,
                items: [{ json: {} }, { json: { result: "ok" } }],
                item_count: 2,
              },
            ],
          },
        ],
      };

      await render(
        <template>
          <OutputContext
            @node={{node}}
            @nodes={{Array node}}
            @connections={{(Array)}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      const itemTitles = [
        ...this.element.querySelectorAll(
          ".workflows-context-panel__item-title"
        ),
      ].map((el) => el.textContent.trim());
      const keys = [
        ...this.element.querySelectorAll(".workflows-schema-field__key-title"),
      ].map((el) => el.textContent.trim());

      assert.deepEqual(itemTitles, []);
      assert.dom(".workflows-context-panel__title-meta").hasText("2 items");
      assert.deepEqual(keys, ["result"]);
    });

    test("combines output indexes into one output schema", async function (assert) {
      const node = {
        clientId: "n1",
        name: "Sample",
        type: "condition:if",
        typeVersion: "1.0",
        configuration: {},
      };
      this.session.lastExecutionRunData = {
        Sample: [
          {
            status: "success",
            outputs: [
              {
                index: 0,
                items: [{ json: { topic: { id: 1 } } }],
                item_count: 1,
              },
              {
                index: 1,
                items: [],
                item_count: 0,
              },
            ],
          },
        ],
      };

      await render(
        <template>
          <OutputContext
            @node={{node}}
            @nodes={{Array node}}
            @connections={{(Array)}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      const subtitles = [
        ...this.element.querySelectorAll(".workflows-context-panel__subtitle"),
      ].map((el) => el.textContent.replace(/\s+/g, " ").trim());
      const keys = [
        ...this.element.querySelectorAll(".workflows-schema-field__key-title"),
      ].map((el) => el.textContent.trim());

      assert.deepEqual(subtitles, []);
      assert
        .dom(
          ".workflows-context-panel__header .workflows-context-panel__title-meta"
        )
        .hasText("1 item");
      assert.dom(".workflows-context-panel__empty").doesNotExist();
      assert.deepEqual(keys, ["topic"]);
    });
  }
);
