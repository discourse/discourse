import { click, fillIn, findAll, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import NodePackImportModal from "discourse/plugins/discourse-workflows/admin/components/workflows/node-pack/import-modal";
import { nodePackDetail, nodePackPreview } from "../../../fixtures/node-packs";

module(
  "Integration | Component | Workflows | NodePack | ImportModal",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    hooks.beforeEach(function () {
      this.set("model", { inline: true });
      this.set("closeModal", () => {});
    });

    hooks.afterEach(function () {
      sinon.restore();
    });

    test("renders server manifest validation errors", async function (assert) {
      pretender.post(
        "/admin/plugins/discourse-workflows/node-packs/preview.json",
        () =>
          response(422, {
            type: "invalid_manifest",
            errors: [
              {
                path: "nodes[2].properties.state.default",
                code: "expression_default_forbidden",
                message: "Expression defaults are not allowed",
              },
            ],
          })
      );

      await render(
        <template>
          <NodePackImportModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );
      await fillIn("textarea", '{"format":"invalid"}');
      await click(
        ".workflows-node-pack-import__choose-form button[type='submit']"
      );

      assert
        .dom(".alert-error")
        .includesText(
          "nodes[2].properties.state.default — Expression defaults are not allowed"
        );
    });

    test("offers credential creation for each slot and passes its context", async function (assert) {
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
      const credentials = [
        nodePackPreview.credentials[0],
        {
          key: "audit",
          label: "Audit API credentials",
          credential_types: ["basic_auth", "header_auth"],
          required: true,
        },
      ];
      pretender.post(
        "/admin/plugins/discourse-workflows/node-packs/preview.json",
        () => response({ preview: { ...nodePackPreview, credentials } })
      );

      await render(
        <template>
          <NodePackImportModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );
      await fillIn("textarea", "{}");
      await click(
        ".workflows-node-pack-import__choose-form button[type='submit']"
      );
      await waitFor(".workflows-node-pack-import__add-credential");

      assert
        .dom(".workflows-node-pack-import__add-credential")
        .exists({ count: 2 }, "each credential slot has its own action");
      await click(findAll(".workflows-node-pack-import__add-credential")[1]);

      assert.deepEqual(modalModel.credentialSlot, {
        ...credentials[1],
        name: "audit",
      });
    });

    test("requires destination approval and installs the preview", async function (assert) {
      Object.defineProperty(
        this.owner.lookup("service:router"),
        "transitionTo",
        {
          configurable: true,
          value() {},
        }
      );
      this.owner.unregister("service:toasts");
      this.owner.register(
        "service:toasts",
        { success() {} },
        { instantiate: false }
      );
      const service = this.owner.lookup("service:workflows-node-types");
      const clear = sinon.spy(service, "clear");
      let installRequest;

      pretender.post(
        "/admin/plugins/discourse-workflows/node-packs/preview.json",
        () => response({ preview: nodePackPreview })
      );
      pretender.post(
        "/admin/plugins/discourse-workflows/node-packs.json",
        (request) => {
          installRequest = JSON.parse(request.requestBody);
          return response(201, {
            node_pack: nodePackDetail,
            result: "installed",
          });
        }
      );

      await render(
        <template>
          <NodePackImportModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );
      await fillIn("textarea", '{"format":"discourse-workflows/node-pack"}');
      await click(
        ".workflows-node-pack-import__choose-form button[type='submit']"
      );
      await waitFor(".workflows-node-pack-import__approval-form");

      const checkboxes = findAll(
        ".workflows-node-pack-import__approval-form input[type='checkbox']"
      );
      assert.true(checkboxes[0].checked, "previous approval is retained");
      assert.false(checkboxes[1].checked, "a new destination needs approval");
      assert
        .dom(".workflows-node-pack-import__approval-form button[type='submit']")
        .isDisabled(
          "installation is blocked until every destination is approved"
        );

      await click(checkboxes[1]);
      await click(
        ".workflows-node-pack-import__approval-form button[type='submit']"
      );

      assert.deepEqual(installRequest.approved_destinations, [
        "https://api.example.com",
        "https://audit.example.com",
      ]);
      assert.true(clear.calledOnce, "the node-type cache is invalidated");
    });

    test("renders a typed definition conflict inline", async function (assert) {
      pretender.post(
        "/admin/plugins/discourse-workflows/node-packs/preview.json",
        () => response({ preview: nodePackPreview })
      );
      pretender.post("/admin/plugins/discourse-workflows/node-packs.json", () =>
        response(409, { type: "definition_conflict" })
      );

      await render(
        <template>
          <NodePackImportModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );
      await fillIn("textarea", "{}");
      await click(
        ".workflows-node-pack-import__choose-form button[type='submit']"
      );
      await waitFor(".workflows-node-pack-import__approval-form");
      for (const checkbox of findAll(
        ".workflows-node-pack-import__approval-form input[type='checkbox']"
      )) {
        if (!checkbox.checked) {
          await click(checkbox);
        }
      }
      await click(
        ".workflows-node-pack-import__approval-form button[type='submit']"
      );

      assert
        .dom(".workflows-node-pack-import__approval-form .alert-error")
        .includesText("without a version bump");
    });
  }
);
