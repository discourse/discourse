import { hash } from "@ember/helper";
import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import NestedRepliesSettingsUpsert from "discourse/connectors/category-custom-settings/nested-replies-settings-upsert";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

class DialogStub extends Service {
  message = null;

  yesNoConfirm(options) {
    this.message = options.message;
    return Promise.resolve(true);
  }
}

module(
  "Integration | Component | NestedRepliesSettingsUpsert",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.nested_replies_enabled = true;
      this.owner.register("service:dialog", DialogStub);
      this.dialog = this.owner.lookup("service:dialog");
    });

    test("prompts admins to save before converting existing topics", async function (assert) {
      this.data = { category_setting: { nested_replies_default: true } };
      this.category = {
        id: 11,
        category_setting: { nested_replies_default: false },
        custom_fields: {},
      };

      await render(
        <template>
          <Form @data={{this.data}} as |form transientData|>
            <NestedRepliesSettingsUpsert
              @outletArgs={{hash
                category=this.category
                form=form
                transientData=transientData
              }}
            />
          </Form>
        </template>
      );

      assert
        .dom(".nested-replies-category-settings__notice")
        .hasText(
          i18n("nested_replies.category_settings.save_first"),
          "the save-first message is shown"
        );
      assert
        .dom(".nested-replies-category-settings__convert-button")
        .doesNotExist(
          "the conversion button is hidden until the setting is saved"
        );
    });

    test("does not show the conversion button after conversion completed", async function (assert) {
      this.data = { category_setting: { nested_replies_default: true } };
      this.category = {
        id: 11,
        category_setting: { nested_replies_default: true },
        custom_fields: { nested_replies_conversion_completed: true },
      };

      await render(
        <template>
          <Form @data={{this.data}} as |form transientData|>
            <NestedRepliesSettingsUpsert
              @outletArgs={{hash
                category=this.category
                form=form
                transientData=transientData
              }}
            />
          </Form>
        </template>
      );

      assert
        .dom(".nested-replies-category-settings__notice")
        .hasText(
          i18n("nested_replies.category_settings.convert_existing_complete"),
          "the completed message is shown"
        );
      assert
        .dom(".nested-replies-category-settings__convert-button")
        .doesNotExist("the conversion button is hidden after completion");
    });

    test("converts existing topics after confirmation", async function (assert) {
      let requestCount = 0;
      pretender.post("/categories/11/convert_nested_replies", () => {
        requestCount++;
        return response({
          success: "OK",
          converted_topic_count: 1,
          nested_replies_conversion_completed: true,
        });
      });

      this.data = { category_setting: { nested_replies_default: true } };
      this.category = {
        id: 11,
        category_setting: { nested_replies_default: true },
        custom_fields: {},
      };

      await render(
        <template>
          <Form @data={{this.data}} as |form transientData|>
            <NestedRepliesSettingsUpsert
              @outletArgs={{hash
                category=this.category
                form=form
                transientData=transientData
              }}
            />
          </Form>
        </template>
      );

      await click(".nested-replies-category-settings__convert-button");

      assert.strictEqual(
        this.dialog.message,
        i18n("nested_replies.category_settings.convert_existing_confirm"),
        "the confirmation message is shown"
      );
      assert.strictEqual(requestCount, 1, "the conversion endpoint is called");
      assert
        .dom(".nested-replies-category-settings__notice")
        .hasText(
          i18n("nested_replies.category_settings.convert_existing_complete"),
          "the completed message is shown after conversion"
        );
      assert
        .dom(".nested-replies-category-settings__convert-button")
        .doesNotExist("the conversion button is hidden after conversion");
    });
  }
);
