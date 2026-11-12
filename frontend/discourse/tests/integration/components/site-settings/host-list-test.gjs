import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import HostList from "discourse/admin/components/site-settings/host-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

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
});
