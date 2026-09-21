import { render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import CredentialModal from "discourse/plugins/discourse-workflows/admin/components/workflows/credential/modal";

const CREDENTIAL_TYPES = [
  {
    identifier: "bearer_token",
    display_name: "Bearer token",
    property_schema: {
      token: { type: "string", required: true, ui: { control: "password" } },
    },
  },
  {
    identifier: "basic_auth",
    display_name: "Basic auth",
    property_schema: {
      user: { type: "string", required: true },
      password: {
        type: "string",
        required: true,
        ui: { control: "password" },
      },
    },
  },
  {
    identifier: "header_auth",
    display_name: "Header auth",
    property_schema: {
      value: { type: "string", required: true },
    },
  },
];

module(
  "Integration | Component | Workflows | Credential | Modal",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.owner.lookup("service:workflows-node-types").clear();
      pretender.get("/admin/plugins/discourse-workflows/node-types.json", () =>
        response({
          node_types: [],
          credential_types: CREDENTIAL_TYPES,
          expression_context: {},
        })
      );
      this.set("closeModal", () => {});
      this.set("onSave", () => {});
    });

    test("auto-selects a single contextual type and renders its secret field", async function (assert) {
      this.set("model", {
        inline: true,
        credential: null,
        credentialSlot: {
          name: "auth",
          label: "Example API token",
          credential_types: ["bearer_token"],
        },
        onSave: this.onSave,
      });

      await render(
        <template>
          <CredentialModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );
      await waitFor("input[name='token']");

      assert
        .dom(".d-modal__title")
        .hasText("Set up credential for Example API token");
      assert
        .dom("select[name='credential_type']")
        .doesNotExist("a single allowed type does not need a picker");
      assert
        .dom("input[name='token']")
        .hasAttribute(
          "type",
          "password",
          "the selected type schema renders immediately"
        );
    });

    test("restricts a contextual picker to supported allowed types", async function (assert) {
      this.set("model", {
        inline: true,
        credential: null,
        credentialSlot: {
          name: "auth",
          credential_types: ["bearer_token", "basic_auth"],
        },
        onSave: this.onSave,
      });

      await render(
        <template>
          <CredentialModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );
      await waitFor("select[name='credential_type']");

      assert.dom("select[name='credential_type'] option").exists({ count: 3 });
      assert.dom("select[name='credential_type']").includesText("Bearer token");
      assert.dom("select[name='credential_type']").includesText("Basic auth");
      assert
        .dom("select[name='credential_type']")
        .doesNotIncludeText(
          "Header auth",
          "types outside the slot are omitted"
        );
    });

    test("keeps the full type picker for standalone creation", async function (assert) {
      this.set("model", {
        inline: true,
        credential: null,
        onSave: this.onSave,
      });

      await render(
        <template>
          <CredentialModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );
      await waitFor("select[name='credential_type']");

      assert.dom("select[name='credential_type'] option").exists({ count: 4 });
      assert.dom("select[name='credential_type']").includesText("Bearer token");
      assert.dom("select[name='credential_type']").includesText("Basic auth");
      assert.dom("select[name='credential_type']").includesText("Header auth");
    });

    test("does not fall back to all types for an empty context", async function (assert) {
      this.set("model", {
        inline: true,
        credential: null,
        credentialSlot: {
          name: "auth",
          credential_types: [],
        },
        onSave: this.onSave,
      });

      await render(
        <template>
          <CredentialModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );
      await waitFor(".alert-error");

      assert.dom("select[name='credential_type']").doesNotExist();
      assert.dom("button[type='submit']").isDisabled();
    });

    test("does not fall back to all types for an unknown context", async function (assert) {
      this.set("model", {
        inline: true,
        credential: null,
        credentialSlot: {
          name: "auth",
          credential_types: ["unknown_type"],
        },
        onSave: this.onSave,
      });

      await render(
        <template>
          <CredentialModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );
      await waitFor(".alert-error");

      assert.dom("select[name='credential_type']").doesNotExist();
      assert.dom("input[name='token']").doesNotExist();
      assert.dom("button[type='submit']").isDisabled();
      assert
        .dom(".alert-error")
        .hasText(
          "No supported credential types are available for this requirement."
        );
    });
  }
);
