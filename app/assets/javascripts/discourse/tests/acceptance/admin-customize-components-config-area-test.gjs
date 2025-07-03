import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Config areas - Components", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/config/customize/components", () => {
      return helper.response({ components: [] });
    });
  });

  test("admin-config-area-components-new-button plugin outlet", async function (assert) {
    withPluginApi("0.1", (api) => {
      api.renderInOutlet(
        "admin-config-area-components-new-button",
        <template>
          <@actions.Primary
            class="my-custom-button"
            @translatedLabel="Hello world"
          />
        </template>
      );
    });

    await visit("/admin/config/customize/components");
    assert
      .dom(".d-page-subheader .my-custom-button")
      .exists("the custom button is rendered in the subheader actions list");
    assert
      .dom(".d-page-subheader .btn")
      .exists(
        { count: 1 },
        "the default button is replaced by the custom button"
      );
  });

  test("admin-config-area-components-empty-list-bottom plugin outlet", async function (assert) {
    withPluginApi("0.1", (api) => {
      api.renderInOutlet(
        "admin-config-area-components-empty-list-bottom",
        <template>
          <div class="my-custom-empty-list">
            Additional message shown at the bottom of the empty list.
          </div>
        </template>
      );
    });

    await visit("/admin/config/customize/components");
    assert
      .dom(".my-custom-empty-list")
      .hasText(
        "Additional message shown at the bottom of the empty list.",
        "the custom empty list message is rendered at the bottom"
      );
  });
});
