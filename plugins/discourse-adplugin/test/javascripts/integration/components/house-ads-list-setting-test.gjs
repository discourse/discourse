import EmberObject from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import HouseAdsListSetting from "discourse/plugins/discourse-adplugin/admin/components/house-ads-list-setting";

module("Integration | Component | HouseAdsListSetting", function (hooks) {
  setupRenderingTest(hooks);

  test("saves the picked ads to the setting", async function (assert) {
    let saved;
    pretender.put(
      "/admin/plugins/discourse-adplugin/house-settings/topic_list_top",
      (request) => {
        saved = new URLSearchParams(request.requestBody).get("value");
        return response({});
      }
    );
    const adSettings = EmberObject.create({ topic_list_top: "first" });
    const allAds = [{ name: "first" }, { name: "second" }];

    await render(
      <template>
        <HouseAdsListSetting
          @adSettings={{adSettings}}
          @allAds={{allAds}}
          @name="topic_list_top"
          @value={{adSettings.topic_list_top}}
        />
      </template>
    );

    assert.dom(".setting-controls .ok").doesNotExist("starts unchanged");

    const chooser = selectKit(".house-ads-chooser");
    await chooser.expand();
    await chooser.selectRowByValue("second");

    assert.dom(".setting-controls .ok").exists("offers to save the change");

    await click(".setting-controls .ok");

    assert.strictEqual(saved, "first|second", "sends the new value");
    assert.strictEqual(
      adSettings.topic_list_top,
      "first|second",
      "updates the settings model"
    );
    assert.dom(".setting-controls .ok").doesNotExist("is unchanged again");
  });
});
