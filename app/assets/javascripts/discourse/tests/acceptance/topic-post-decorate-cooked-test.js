import Component from "@glimmer/component";
import { hbs } from "ember-cli-htmlbars";
import { setComponentTemplate } from "@ember/component";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { withPluginApi } from "discourse/lib/plugin-api";

acceptance("Acceptance | decorateCookedElement", function () {
  test("decorator with renderGlimmer works", async function (assert) {
    class DemoComponent extends Component {
      static eventLog = [];
      constructor() {
        DemoComponent.eventLog.push("created");
        return super(...arguments);
      }
      willDestroy() {
        DemoComponent.eventLog.push("willDestroy");
      }
    }
    setComponentTemplate(
      hbs`<span class='glimmer-component-content'>Hello world</span>`,
      DemoComponent
    );

    withPluginApi(0, (api) => {
      api.decorateCookedElement((cooked, helper) => {
        if (helper.getModel().post_number !== 1) {
          return;
        }
        cooked.appendChild(
          helper.renderGlimmer(
            "div.glimmer-wrapper",
            hbs`<@data.component />`,
            { component: DemoComponent }
          )
        );
      });
    });

    await visit("/t/internationalization-localization/280");

    assert.dom("div.glimmer-wrapper").exists();
    assert.dom("span.glimmer-component-content").exists();
    assert.deepEqual(DemoComponent.eventLog, ["created"]);

    await visit("/");

    assert.deepEqual(DemoComponent.eventLog, ["created", "willDestroy"]);
  });
});
