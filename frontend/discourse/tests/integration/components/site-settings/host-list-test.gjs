import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import HostList from "discourse/admin/components/site-settings/host-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

module("Integration | Component | SiteSettings | HostList", function (hooks) {
  setupRenderingTest(hooks);

  test("reports changes as a pipe-joined string and follows @value", async function (assert) {
    const settingValue = tracked("a.com|b.com");
    const setting = { setting: "blocked_onebox_domains" };
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      settingValue.value = value;
    };

    await render(
      <template>
        <HostList
          @allowAny={{true}}
          @changeValueCallback={{changeValue}}
          @setting={{setting}}
          @value={{settingValue.value}}
        />
      </template>
    );

    const subject = selectKit(".list-setting");
    await subject.expand();
    await subject.fillInFilter("c.com");
    await subject.keyboard("Enter");

    assert.deepEqual(changes, ["a.com|b.com|c.com"], "reports the new list");

    await subject.fillInFilter("*.d.com");
    await subject.keyboard("Enter");

    assert.deepEqual(changes, ["a.com|b.com|c.com"], "ignores wildcard hosts");

    settingValue.value = "z.com";
    await settled();

    assert.strictEqual(
      subject.header().value(),
      "z.com",
      "renders a value set by the caller"
    );
  });

  test("adds typed hosts and follows @value with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const settingValue = tracked("a.com|b.com");
    const setting = { setting: "blocked_onebox_domains" };
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      settingValue.value = value;
    };

    await render(
      <template>
        <HostList
          @allowAny={{true}}
          @changeValueCallback={{changeValue}}
          @label="Blocked onebox domains"
          @setting={{setting}}
          @value={{settingValue.value}}
        />
      </template>
    );

    assert.dom(".d-select").hasAttribute("data-name", "a.com,b.com");
    assert
      .dom(".d-select__input")
      .hasAttribute(
        "placeholder",
        i18n("admin.site_settings.host_list.add_more_placeholder"),
        "a field holding hosts asks for another"
      );

    await dSelect(".d-select").search("c.com");
    await click("[role='option'].--create");
    assert.deepEqual(changes, ["a.com|b.com|c.com"], "reports the new list");

    await dSelect(".d-select").search("*.d.com");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("a wildcard host can't be added");
    assert
      .dom(".d-select__empty")
      .hasText(
        i18n("admin.site_settings.host_list.not_allowed"),
        "says why instead of reporting no results"
      );

    settingValue.value = "z.com";
    await settled();
    assert
      .dom(".d-select")
      .hasAttribute("data-name", "z.com", "renders a value set by the caller");
  });

  test("takes no typed hosts when the setting refuses them, and follows @disabled, under the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = { setting: "blocked_onebox_domains" };
    const disabled = tracked(false);
    const changeValue = () => {};

    await render(
      <template>
        <HostList
          @allowAny={{false}}
          @changeValueCallback={{changeValue}}
          @disabled={{disabled.value}}
          @label="Blocked onebox domains"
          @setting={{setting}}
          @value=""
        />
      </template>
    );

    assert
      .dom(".d-select__input")
      .hasAttribute(
        "placeholder",
        i18n("admin.site_settings.host_list.placeholder"),
        "the empty field asks for a host"
      );

    await dSelect(".d-select").search("c.com");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("no typed host is offered");

    await dSelect(".d-select").close();
    disabled.value = true;
    await settled();
    assert
      .dom(".d-select [role='combobox']")
      .isDisabled("the picker follows the setting's disabled state");
  });
});
