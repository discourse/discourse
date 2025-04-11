import Component from "@glimmer/component";
import { setComponentTemplate } from "@ember/component";
import { visit } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Acceptance | decorateCookedElement (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
      });

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

              helper.renderGlimmer(
                cooked,
                <template><@data.component /></template>,
                {
                  component: DemoComponent,
                }
              );

              // Append to existing element
              helper.renderGlimmer(
                cooked.querySelector(".existing-wrapper"),
                <template>
                  <span>with more content from glimmer</span>
                </template>
              );
            },
            { onlyStream: true }
          );
        });

        await visit("/t/internationalization-localization/280");

        assert.dom("span.glimmer-component-content").exists();

        assert.dom("div.existing-wrapper").exists();
        assert
          .dom("div.existing-wrapper span")
          .hasText("with more content from glimmer");

        assert.deepEqual(DemoComponent.eventLog, ["created"]);

        await visit("/");

        assert.deepEqual(DemoComponent.eventLog, ["created", "willDestroy"]);
      });
    }
  );
});
