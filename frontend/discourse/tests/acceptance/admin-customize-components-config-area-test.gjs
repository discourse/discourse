import { click, currentURL, fillIn, select, visit } from "@ember/test-helpers";
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
    withPluginApi((api) => {
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
    withPluginApi((api) => {
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

acceptance("Admin - Config areas - Components - filters", function (needs) {
  needs.user();

  let requests;

  needs.hooks.beforeEach(() => {
    requests = [];
  });

  needs.pretender((server, helper) => {
    const components = [
      { id: 1, name: "Air", parent_themes: [], enabled: true },
      {
        id: 2,
        name: "Ground",
        parent_themes: [{ id: 5, name: "Horizon" }],
        enabled: true,
      },
    ];

    server.get("/admin/config/customize/components", (request) => {
      requests.push(request.queryParams);

      const { name, status } = request.queryParams;
      let filtered = components;

      if (name) {
        filtered = filtered.filter((component) =>
          component.name.toLowerCase().includes(name.toLowerCase())
        );
      }

      if (status === "used") {
        filtered = filtered.filter(
          (component) => component.parent_themes.length > 0
        );
      } else if (status === "unused") {
        filtered = filtered.filter(
          (component) => component.parent_themes.length === 0
        );
      }

      return helper.response({
        components: filtered,
        has_more: false,
      });
    });
  });

  test("seeds the filters from the URL before the first request", async function (assert) {
    await visit("/admin/config/customize/components?filter=air&status=unused");

    assert.strictEqual(
      requests.length,
      1,
      "makes a single request on load, with no unfiltered request first"
    );
    assert.strictEqual(
      requests[0].name,
      "air",
      "the first request includes the name filter from the URL"
    );
    assert.strictEqual(
      requests[0].status,
      "unused",
      "the first request includes the status filter from the URL"
    );
    assert
      .dom(".admin-filter-controls__input")
      .hasValue("air", "prefills the search input from the URL");
    assert
      .dom(".admin-filter-controls__dropdown")
      .hasValue("unused", "preselects the status dropdown from the URL");
    assert.dom(".admin-config-components__component-row").exists({ count: 1 });
  });

  test("ignores an invalid status param in the URL", async function (assert) {
    await visit("/admin/config/customize/components?status=banana");

    assert.strictEqual(
      requests[0].status,
      undefined,
      "does not send the invalid status to the server"
    );
    assert
      .dom(".admin-filter-controls__dropdown")
      .hasValue("all", "the status dropdown falls back to the default value");
    assert.dom(".admin-config-components__component-row").exists({ count: 2 });
  });

  test("reflects the search in the URL as the user types", async function (assert) {
    await visit("/admin/config/customize/components");

    await fillIn(".admin-filter-controls__input", "air");

    assert.strictEqual(
      requests.at(-1).name,
      "air",
      "sends the name filter to the server"
    );
    assert.strictEqual(
      currentURL(),
      "/admin/config/customize/components?filter=air",
      "reflects the search in the URL"
    );
    assert.dom(".admin-config-components__component-row").exists({ count: 1 });
    assert
      .dom(".admin-filter-controls__input")
      .isFocused("keeps focus while the URL updates");

    await fillIn(".admin-filter-controls__input", "");

    assert.strictEqual(
      currentURL(),
      "/admin/config/customize/components",
      "clearing the search removes the param from the URL"
    );
    assert.dom(".admin-config-components__component-row").exists({ count: 2 });
  });

  test("reflects the status dropdown in the URL", async function (assert) {
    await visit("/admin/config/customize/components");

    await select(".admin-filter-controls__dropdown", "used");

    assert.strictEqual(
      requests.at(-1).status,
      "used",
      "sends the status filter to the server"
    );
    assert.strictEqual(
      currentURL(),
      "/admin/config/customize/components?status=used",
      "reflects the status in the URL"
    );
    assert.dom(".admin-config-components__component-row").exists({ count: 1 });

    await select(".admin-filter-controls__dropdown", "all");

    assert.strictEqual(
      currentURL(),
      "/admin/config/customize/components",
      "selecting the default status removes the param from the URL"
    );
    assert.dom(".admin-config-components__component-row").exists({ count: 2 });
  });

  test("resetting the filters clears the params from the URL", async function (assert) {
    await visit("/admin/config/customize/components?filter=air&status=unused");

    await click(".admin-filter-controls__reset");

    assert.strictEqual(
      currentURL(),
      "/admin/config/customize/components",
      "removes both params in a single URL update"
    );
    assert.dom(".admin-filter-controls__input").hasValue("");
    assert.dom(".admin-filter-controls__dropdown").hasValue("all");
    assert.strictEqual(
      requests.at(-1).name,
      "",
      "reloads without the name filter"
    );
    assert.strictEqual(
      requests.at(-1).status,
      "",
      "reloads without the status filter"
    );
    assert.dom(".admin-config-components__component-row").exists({ count: 2 });
  });

  test("deep linking to filters with no results still renders the filter controls", async function (assert) {
    await visit("/admin/config/customize/components?filter=nomatch");

    assert
      .dom(".admin-filter-controls")
      .exists("the filter controls render despite the empty filtered result");
    assert
      .dom(".admin-filter-controls__input")
      .hasValue("nomatch", "prefills the search input from the URL");
    assert.dom(".admin-config-components__component-row").doesNotExist();
    assert
      .dom(".admin-filter-controls__no-results .admin-filter-controls__reset")
      .exists("a reset button renders alongside the no-results message");
    assert
      .dom(".admin-config-area-empty-list")
      .doesNotExist("the no-components-installed empty state is not shown");
  });
});
