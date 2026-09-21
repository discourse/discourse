import { click, render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import Credential from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/credential";

module(
  "Integration | Component | Workflows | Configurators | Credential",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.modalOptions = null;
      this.owner.unregister("service:modal");
      this.owner.register(
        "service:modal",
        {
          show: (_component, options) => {
            this.modalOptions = options;
          },
        },
        { instantiate: false }
      );
      this.onChange = sinon.spy();
      this.credentialTypes = ["bearer_token"];

      pretender.get("/admin/plugins/discourse-workflows/credentials.json", () =>
        response({ credentials: [] })
      );
    });

    hooks.afterEach(function () {
      sinon.restore();
    });

    test("passes slot context and selects a newly saved credential", async function (assert) {
      pretender.post(
        "/admin/plugins/discourse-workflows/credentials.json",
        () =>
          response(201, {
            credential: {
              id: 42,
              name: "Production token",
              credential_type: "bearer_token",
            },
          })
      );

      await render(
        <template>
          <Credential
            @credentialName="auth"
            @credentialTypes={{this.credentialTypes}}
            @label="Example API token"
            @onChange={{this.onChange}}
          />
        </template>
      );
      await waitFor(".workflows-property-engine__select-with-action .btn");
      await click(".workflows-property-engine__select-with-action .btn");

      assert.deepEqual(this.modalOptions.model.credentialSlot, {
        name: "auth",
        label: "Example API token",
        credential_types: ["bearer_token"],
      });

      await this.modalOptions.model.onSave({
        name: "Production token",
        credential_type: "bearer_token",
        data: { token: "not-a-real-secret" },
      });
      await settled();

      assert.true(
        this.onChange.calledWith({
          id: "42",
          credential_type: "bearer_token",
        }),
        "the new credential is selected on the node"
      );
    });
  }
);
