import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import formKit from "discourse/tests/helpers/form-kit-helper";
import HouseAdForm from "discourse/plugins/discourse-adplugin/admin/components/house-ad-form";

module("Integration | Component | HouseAdForm", function (hooks) {
  setupRenderingTest(hooks);

  test("with the new select controls, saves the picked group ids", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.owner.lookup("service:site").groups = [
      { id: 10, name: "support", automatic: false },
      { id: 11, name: "sales", automatic: false },
    ];
    sinon.stub(this.owner.lookup("service:router"), "transitionTo");
    let body;
    pretender.put(
      "/admin/plugins/discourse-adplugin/house-ads/3",
      (request) => {
        body = parsePostData(request.requestBody);
        return response({ house_ad: { id: 3 } });
      }
    );
    const model = {
      id: 3,
      name: "Ad",
      html: "<p>Ad</p>",
      visible_to_logged_in_users: true,
      visible_to_anons: true,
      categories: [],
      groups: [10],
      routes: [],
    };
    const houseAds = [model];

    await render(
      <template>
        <HouseAdForm @houseAds={{houseAds}} @model={{model}} />
      </template>
    );

    const groups = dSelect(".group-chooser");
    await groups.open();
    await groups.selectByName("sales");
    await groups.close();
    await formKit().submit();

    assert.deepEqual(body["group_ids[]"], ["10", "11"]);
  });

  test("with the new select controls, the categories picker is described by the field's description", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const model = {
      id: 3,
      name: "Ad",
      html: "<p>Ad</p>",
      categories: [],
      groups: [],
      routes: [],
    };
    const houseAds = [model];

    await render(
      <template>
        <HouseAdForm @houseAds={{houseAds}} @model={{model}} />
      </template>
    );

    const description = find(
      "[data-name='categories'] .form-kit__container-description"
    );
    assert
      .dom("[data-name='categories'] [role='combobox']")
      .hasAttribute("aria-describedby", new RegExp(description.id));
  });
});
