import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { withPluginApi } from "discourse/lib/plugin-api";
import { registerTemporaryModule } from "../helpers/temporary-module-helper";

const PREFIX = "discourse/plugins/some-plugin/templates/connectors";

acceptance("Plugin Outlet - Decorator", function (needs) {
  needs.user();

  needs.hooks.beforeEach(() => {
    registerTemporaryModule(
      `${PREFIX}/discovery-list-container-top/foo`,
      hbs`FOO`
    );
    registerTemporaryModule(
      `${PREFIX}/discovery-list-container-top/bar`,
      hbs`BAR`
    );

    withPluginApi("0.8.38", (api) => {
      api.decoratePluginOutlet(
        "discovery-list-container-top",
        (elem, args) => {
          if (elem.classList.contains("foo")) {
            elem.style.backgroundColor = "yellow";

            if (args.category) {
              elem.classList.add("in-category");
            } else {
              elem.classList.remove("in-category");
            }
          }
        },
        { id: "yellow-decorator" }
      );
    });
  });

  test("Calls the plugin callback with the rendered outlet", async function (assert) {
    await visit("/");

    const fooConnector = queryAll(
      ".discovery-list-container-top-outlet.foo "
    )[0];
    const barConnector = queryAll(
      ".discovery-list-container-top-outlet.bar "
    )[0];

    assert.ok(exists(fooConnector));
    assert.strictEqual(fooConnector.style.backgroundColor, "yellow");
    assert.strictEqual(barConnector.style.backgroundColor, "");

    await visit("/c/bug");

    assert.ok(fooConnector.classList.contains("in-category"));

    await visit("/");

    assert.notOk(fooConnector.classList.contains("in-category"));
  });
});
