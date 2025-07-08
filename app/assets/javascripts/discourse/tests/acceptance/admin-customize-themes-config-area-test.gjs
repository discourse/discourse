import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Config areas - Themes", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/config/customize/themes", () => {
      return helper.response({ themes: [] });
    });
  });

  test("admin-themes-grid-additional-cards plugin outlet", async function (assert) {
    withPluginApi("0.1", (api) => {
      api.renderInOutlet(
        "admin-themes-grid-additional-cards",
        <template>
          <@AdminConfigAreaCardComponent class="my-test-card">
            <:content>
              Hello, this is a test card.
            </:content>
          </@AdminConfigAreaCardComponent>
        </template>
      );
    });

    await visit("/admin/config/customize/themes");
    assert
      .dom(".my-test-card")
      .hasText(
        "Hello, this is a test card.",
        "the custom card is rendered correctly"
      );
  });

  test("admin-config-area-themes-new-button plugin outlet", async function (assert) {
    withPluginApi("0.1", (api) => {
      api.renderInOutlet(
        "admin-config-area-themes-new-button",
        <template>
          <@actions.Primary
            class="my-custom-button"
            @translatedLabel="Hello world"
          />
        </template>
      );
    });

    await visit("/admin/config/customize/themes");
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
});
