import { click, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import CredentialsManager from "discourse/plugins/discourse-workflows/admin/components/workflows/credential/manager";

module(
  "Integration | Component | Workflows | Credential | CredentialsManager",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.connection = { status: "not_connected" };
      pretender.get("/admin/plugins/discourse-workflows/credentials.json", () =>
        response(200, {
          credentials: [
            {
              id: 42,
              name: "Contacts API",
              credential_type: "oauth2_client_credentials",
              display_name: "OAuth2 (Client credentials)",
              data: {
                token_url: "https://auth.example.com/token",
                api_origin: "https://api.example.com",
                client_id: "client",
                client_secret: "__REDACTED__",
              },
              oauth_connection: this.connection,
            },
          ],
          meta: { total_rows: 1 },
        })
      );
    });

    test("tests a saved credential and displays the connected status", async function (assert) {
      let connectRequests = 0;
      pretender.post(
        "/admin/plugins/discourse-workflows/credentials/42/connect.json",
        () => {
          connectRequests++;
          this.connection = { status: "connected" };
          return response(200, {
            credential: { id: 42, oauth_connection: this.connection },
          });
        }
      );

      const toasts = this.owner.lookup("service:toasts");
      await render(<template><CredentialsManager /></template>);
      await waitFor(".workflows-credential-connection__connect");
      assert
        .dom(".workflows-credential-connection__status")
        .hasText(
          i18n("discourse_workflows.oauth2.statuses.not_connected"),
          "the connection has not been tested yet"
        );
      await click(".workflows-credential-connection__connect");

      assert.strictEqual(
        connectRequests,
        1,
        "the connection is tested with one POST"
      );
      assert
        .dom(".workflows-credential-connection__status")
        .hasText(
          i18n("discourse_workflows.oauth2.statuses.connected"),
          "the list displays the tested connection"
        );
      assert.deepEqual(
        toasts.activeToasts.map((toast) => ({
          message: toast.options.data.message,
          theme: toast.options.data.theme,
        })),
        [
          {
            message: i18n("discourse_workflows.oauth2.results.connected"),
            theme: "success",
          },
        ],
        "successful authentication creates one success notification"
      );
    });

    test("active connections stay compact in the list and offer Test connection", async function (assert) {
      this.connection = {
        status: "connected",
        details: [
          { label: "Account", value: "admin@example.com" },
          { label: "Organization", value: "00Dorg" },
        ],
        last_refreshed_at: "2026-09-08T12:00:00Z",
      };

      await render(<template><CredentialsManager /></template>);
      await waitFor(".workflows-credential-connection__connect");

      assert
        .dom(".workflows-credential-connection__status")
        .hasText(
          i18n("discourse_workflows.oauth2.statuses.connected"),
          "the persisted status is active"
        );
      assert
        .dom(".workflows-credential-connection__details")
        .doesNotExist("connection details do not expand the table row");
      assert
        .dom(".workflows-credential-connection__connect")
        .hasText(
          i18n("discourse_workflows.oauth2.test_connection"),
          "Test connection is available"
        );
    });

    test("failed connection tests display a safe error and keep the credential unconnected", async function (assert) {
      pretender.post(
        "/admin/plugins/discourse-workflows/credentials/42/connect.json",
        () =>
          response(422, {
            errors: ["Contacts API rejected the app credentials."],
          })
      );
      await render(<template><CredentialsManager /><DialogHolder /></template>);
      await waitFor(".workflows-credential-connection__connect");
      await click(".workflows-credential-connection__connect");

      assert
        .dom(".dialog-body")
        .containsText(
          "Contacts API rejected the app credentials.",
          "the server error is displayed"
        );
      assert
        .dom(".workflows-credential-connection__status")
        .hasText(
          i18n("discourse_workflows.oauth2.statuses.not_connected"),
          "the credential remains unconnected"
        );
    });
  }
);
