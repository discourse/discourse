import { click, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import NodePackDetail from "discourse/plugins/discourse-workflows/admin/components/workflows/node-pack/detail";
import NodePackManager from "discourse/plugins/discourse-workflows/admin/components/workflows/node-pack/manager";
import { nodePackDetail, nodePackSummary } from "../../../fixtures/node-packs";

module(
  "Integration | Component | Workflows | NodePack | Manager",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    test("renders the node pack list contract", async function (assert) {
      pretender.get("/admin/plugins/discourse-workflows/node-packs.json", () =>
        response({
          node_packs: [nodePackSummary],
          meta: { total_rows: 1 },
        })
      );

      await render(<template><NodePackManager /></template>);
      await waitFor("[data-item-id='7']");

      assert.dom(".d-table__overview-name").hasText("Example pack");
      assert.dom("[data-item-id='7']").includesText("example_pack");
      assert.dom("[data-item-id='7']").includesText("4 active · 1 retired");
      assert.dom("[data-item-id='7']").includesText("Enabled");
      assert
        .dom("[data-item-id='7'] .relative-date")
        .hasAttribute(
          "data-time",
          "1789948800000",
          "the updated timestamp uses the standard date formatter"
        );
    });
  }
);

module(
  "Integration | Component | Workflows | NodePack | Detail",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    test("renders nodes, approved origins, credentials, and usage", async function (assert) {
      pretender.get(
        "/admin/plugins/discourse-workflows/node-packs/7.json",
        () => response({ node_pack: nodePackDetail })
      );

      await render(<template><NodePackDetail @id={{7}} /></template>);
      await waitFor(".workflows-node-packs__detail-header");

      assert.dom(".d-page-subheader__title").hasText("Example pack");
      assert
        .dom(".workflows-node-packs__description")
        .hasText("Generic declarative actions");
      assert.dom(".workflows-node-packs__table").exists({ count: 2 });
      assert.dom("code").includesText("action:example_pack.choice");
      assert
        .dom(".workflows-node-packs__destinations")
        .includesText("https://api.example.com");
      assert
        .dom(".workflows-node-packs__credential-list")
        .includesText("Example API token");
      assert.dom(".alert-warning").includesText("2 active executions");
      assert
        .dom(".workflows-node-packs__detail-header a")
        .hasAttribute(
          "href",
          "https://example.com/docs",
          "the HTTPS homepage is linked"
        );
      assert
        .dom(".workflows-node-packs__detail-header a")
        .hasText("About ↗", "the homepage link uses the concise About label");
      assert
        .dom(
          ".workflows-node-packs__detail-header .workflows-node-packs__pack-icon"
        )
        .doesNotExist("the detail header has no decorative pack icon");
    });

    test("passes the single credential slot to credential creation", async function (assert) {
      let modalModel;
      this.owner.unregister("service:modal");
      this.owner.register(
        "service:modal",
        {
          show: (_component, options) => {
            modalModel = options.model;
          },
        },
        { instantiate: false }
      );
      pretender.get(
        "/admin/plugins/discourse-workflows/node-packs/7.json",
        () => response({ node_pack: nodePackDetail })
      );

      await render(<template><NodePackDetail @id={{7}} /></template>);
      await waitFor(".workflows-node-packs__add-credential");
      await click(".workflows-node-packs__add-credential");

      assert.deepEqual(modalModel.credentialSlot, {
        ...nodePackDetail.credentials[0],
        name: "api",
      });
    });

    test("translates the disable confirmation label once", async function (assert) {
      pretender.get(
        "/admin/plugins/discourse-workflows/node-packs/7.json",
        () => response({ node_pack: nodePackDetail })
      );

      await render(
        <template>
          <DialogHolder />
          <NodePackDetail @id={{7}} />
        </template>
      );
      await waitFor(".workflows-node-packs__detail-header");
      await click(".d-page-subheader__actions .btn:first-child");

      assert
        .dom(".dialog-footer .btn-primary")
        .hasText("Disable", "the translation key is rendered as its label");
    });

    test("does not link an unsafe homepage", async function (assert) {
      pretender.get(
        "/admin/plugins/discourse-workflows/node-packs/7.json",
        () =>
          response({
            node_pack: {
              ...nodePackDetail,
              description: "<img src=x onerror=alert(1)>",
              homepage: ["javascript", "alert(1)"].join(":"),
            },
          })
      );

      await render(<template><NodePackDetail @id={{7}} /></template>);
      await waitFor(".workflows-node-packs__detail-header");

      assert
        .dom(".workflows-node-packs__description")
        .hasText(
          "<img src=x onerror=alert(1)>",
          "manifest text remains escaped"
        );
      assert
        .dom(".workflows-node-packs__description img")
        .doesNotExist("manifest text cannot insert markup");
      assert
        .dom(".workflows-node-packs__detail-header a")
        .doesNotExist("a non-HTTPS homepage is not linked");
    });
  }
);
