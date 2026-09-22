import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import CredentialModal from "discourse/plugins/discourse-workflows/admin/components/workflows/credential/modal";

const noop = () => {};

const CREDENTIAL_TYPE = {
  identifier: "oauth2_client_credentials",
  display_name: "OAuth2 (Client credentials)",
  oauth2: true,
  ui: { i18n_scope: "oauth2" },
  property_schema: {
    client_id: { type: "string", required: true },
    token_url: { type: "string", required: true },
    api_origin: { type: "string", required: true },
    revoke_url: { type: "string", required: false, ui: { advanced: true } },
    scope: { type: "string", required: false, ui: { advanced: true } },
  },
};

module(
  "Integration | Component | Workflows | Credential | CredentialModal",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/admin/plugins/discourse-workflows/node-types.json", () =>
        response(200, { node_types: [], credential_types: [CREDENTIAL_TYPE] })
      );
    });

    async function renderModal(context, credential) {
      await render(<template><ModalContainer /></template>);
      context.owner.lookup("service:modal").show(CredentialModal, {
        model: { credential, onSave: noop },
      });
      await settled();
      await waitFor("input[name='client_id']");
    }

    test("keeps optional fields behind a collapsed Advanced disclosure", async function (assert) {
      await renderModal(this, {
        id: 1,
        name: "Contacts API",
        credential_type: "oauth2_client_credentials",
        data: {
          client_id: "client",
          token_url: "https://auth.example.com/token",
          api_origin: "https://api.example.com",
        },
      });

      assert.dom("input[name='api_origin']").exists("required fields render");
      assert
        .dom(".workflows-credential-modal__advanced")
        .exists("the disclosure is present")
        .doesNotHaveAttribute("open", "and starts collapsed");
      assert
        .dom(".workflows-credential-modal__advanced-summary")
        .hasText(i18n("discourse_workflows.credentials.advanced"));
      assert
        .dom(".workflows-credential-modal__advanced input[name='scope']")
        .exists("optional fields live inside it");
    });

    test("opens the disclosure when an optional field already has a value", async function (assert) {
      await renderModal(this, {
        id: 1,
        name: "Contacts API",
        credential_type: "oauth2_client_credentials",
        data: {
          client_id: "client",
          token_url: "https://auth.example.com/token",
          api_origin: "https://api.example.com",
          revoke_url: "https://auth.example.com/revoke",
        },
      });

      assert
        .dom(".workflows-credential-modal__advanced")
        .hasAttribute("open", "", "so editing never hides what was configured");
    });
  }
);
