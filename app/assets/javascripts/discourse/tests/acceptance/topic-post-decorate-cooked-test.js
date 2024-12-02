import Component from "@glimmer/component";
import { setComponentTemplate } from "@ember/component";
import { visit } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Acceptance | decorateCookedElement", function () {
  test("decorator with renderGlimmer works", async function (assert) {
    class DemoComponent extends Component {
      static eventLog = [];
      constructor() {
        DemoComponent.eventLog.push("created");
        super(...arguments);
      }

      willDestroy() {
        super.willDestroy(...arguments);
        DemoComponent.eventLog.push("willDestroy");
      }
    }
    setComponentTemplate(
      hbs`<span class='glimmer-component-content'>Hello world</span>`,
      DemoComponent
    );

    withPluginApi(0, (api) => {
      api.decorateCookedElement(
        (cooked, helper) => {
          if (helper.getModel().post_number !== 1) {
            return;
          }
          cooked.innerHTML =
            "<div class='existing-wrapper'>Some existing content</div>";

          // Create new wrapper element and append
          cooked.appendChild(
            helper.renderGlimmer(
              "div.glimmer-wrapper",
              hbs`<@data.component />`,
              { component: DemoComponent }
            )
          );

          // Append to existing element
          helper.renderGlimmer(
            cooked.querySelector(".existing-wrapper"),
            hbs` with more content from glimmer`
          );
        },
        { onlyStream: true }
      );
    });

    await visit("/t/internationalization-localization/280");

    assert.dom("div.glimmer-wrapper").exists();
    assert.dom("span.glimmer-component-content").exists();

    assert.dom("div.existing-wrapper").exists();
    assert
      .dom("div.existing-wrapper")
      .hasText("Some existing content with more content from glimmer");

    assert.deepEqual(DemoComponent.eventLog, ["created"]);

    await visit("/");

    assert.deepEqual(DemoComponent.eventLog, ["created", "willDestroy"]);
  });
});
