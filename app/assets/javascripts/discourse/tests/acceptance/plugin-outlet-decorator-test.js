import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { withPluginApi } from "discourse/lib/plugin-api";

const PREFIX = "javascripts/single-test/connectors";

acceptance("Plugin Outlet - Decorator", function (needs) {
  needs.user();

  needs.hooks.beforeEach(() => {
    Ember.TEMPLATES[
      `${PREFIX}/discovery-list-container-top/foo`
    ] = Ember.HTMLBars.compile("FOO");
    Ember.TEMPLATES[
      `${PREFIX}/discovery-list-container-top/bar`
    ] = Ember.HTMLBars.compile("BAR");

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

  needs.hooks.afterEach(() => {
    delete Ember.TEMPLATES[`${PREFIX}/discovery-list-container-top/foo`];
    delete Ember.TEMPLATES[`${PREFIX}/discovery-list-container-top/bar`];
  });

  test("Calls the plugin callback with the rendered outlet", async (assert) => {
    await visit("/");

    const fooConnector = find(".discovery-list-container-top-outlet.foo ")[0];
    const barConnector = find(".discovery-list-container-top-outlet.bar ")[0];

    assert.ok(exists(fooConnector));
    assert.equal(fooConnector.style.backgroundColor, "yellow");
    assert.equal(barConnector.style.backgroundColor, "");

    await visit("/c/bug");

    assert.ok(fooConnector.classList.contains("in-category"));

    await visit("/");

    assert.notOk(fooConnector.classList.contains("in-category"));
  });
});
