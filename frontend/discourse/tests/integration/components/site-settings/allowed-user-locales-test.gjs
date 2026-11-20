import { tracked } from "@glimmer/tracking";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AllowedUserLocales from "discourse/admin/components/site-settings/allowed-user-locales";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module(
  "Integration | Component | Site Setting | allowed-user-locales",
  function (hooks) {
    setupRenderingTest(hooks);

    test("submits the two policy values and a list of selected locales", async function (assert) {
      this.siteSettings.available_locales = [
        { name: "English", value: "en" },
        { name: "Japanese", value: "ja" },
      ];
      const policy = tracked("all");

      const update = (value) => (policy.value = value);
      await render(
        <template>
          <AllowedUserLocales
            @changeValueCallback={{update}}
            @value={{policy.value}}
          />
        </template>
      );

      const mode = selectKit(".combo-box");
      await mode.expand();
      await mode.selectRowByValue("selected");
      assert.strictEqual(
        policy.value,
        "",
        "an empty selection cannot save the previous policy"
      );

      const languages = selectKit(".multi-select");
      await languages.expand();
      await languages.selectRowByValue("ja");
      assert.strictEqual(policy.value, "ja");

      await mode.expand();
      await mode.selectRowByValue("none");
      assert.strictEqual(policy.value, "none");
      assert.dom(".multi-select").doesNotExist();

      await mode.expand();
      await mode.selectRowByValue("all");
      assert.strictEqual(policy.value, "all");
    });
  }
);
