import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import AiThemeTranslationModal from "discourse/plugins/discourse-ai/discourse/components/modal/ai-theme-translation-modal";

module(
  "Integration | Component | Modal | AiThemeTranslationModal",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.available_locales = [
        { name: "English", value: "en" },
        { name: "French", value: "fr" },
        { name: "Spanish", value: "es" },
      ];
      this.siteSettings.content_localization_supported_locales = "en|fr|es";
      this.model = {
        theme: { id: 1, name: "Community welcome" },
        locale: "en",
      };
      this.closed = false;
      this.closeModal = () => (this.closed = true);
      this.requests = [];
      pretender.post(
        "/admin/plugins/discourse-ai/ai-theme-translations",
        (request) => {
          this.requests.push(new URLSearchParams(request.requestBody));
          return [204, {}, ""];
        }
      );
    });

    for (const replace of [false, true]) {
      test(`confirms languages and submits override_existing=${replace}`, async function (assert) {
        await render(
          <template>
            <AiThemeTranslationModal
              @closeModal={{this.closeModal}}
              @inline={{true}}
              @model={{this.model}}
            />
          </template>
        );

        assert
          .dom(".ai-theme-translation-modal")
          .includesText("Translate from English");
        assert
          .dom(".ai-theme-translation-modal__languages")
          .hasText("French Spanish");
        assert.dom('input[name="override_existing"]').isNotChecked();
        assert.strictEqual(this.requests.length, 0);
        if (replace) {
          await click('input[name="override_existing"]');
        }
        await formKit().submit();

        assert.strictEqual(this.requests.length, 1);
        assert.strictEqual(
          this.requests[0].get("override_existing"),
          String(replace)
        );
        assert.strictEqual(this.requests[0].get("locale"), "en");
        assert.deepEqual(this.requests[0].getAll("target_locales[]"), [
          "fr",
          "es",
        ]);
        assert.true(this.closed);
      });
    }

    test("does not offer to submit without target languages", async function (assert) {
      this.siteSettings.content_localization_supported_locales = "en";
      await render(
        <template>
          <AiThemeTranslationModal
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );
      assert
        .dom(".ai-theme-translation-modal")
        .includesText("No other target languages");
      assert.dom('button[type="submit"]').doesNotExist();
      assert.strictEqual(this.requests.length, 0);
    });
  }
);
