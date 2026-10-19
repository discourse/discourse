import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ScreenedIpAddressForm from "discourse/admin/components/screened-ip-address-form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | ScreenedIpAddressForm", function (hooks) {
  setupRenderingTest(hooks);

  test("reports the added address and clears the input", async function (assert) {
    pretender.post("/admin/logs/screened_ip_addresses.json", (request) => {
      const params = new URLSearchParams(request.requestBody);
      return response({
        screened_ip_address: {
          id: 1,
          ip_address: params.get("ip_address"),
          action_name: params.get("action_name"),
        },
      });
    });
    const added = [];
    const recordAdded = (record) => added.push(record);

    await render(
      <template><ScreenedIpAddressForm @action={{recordAdded}} /></template>
    );
    await fillIn(".ip-address-input", "1.2.3.4");
    await click(".screened-ip-address-form .btn-default");

    assert.deepEqual(
      added.map((record) => [record.ip_address, record.action_name]),
      [["1.2.3.4", "block"]],
      "reports the saved address"
    );
    assert.dom(".ip-address-input").hasValue("", "clears the input");
    assert.dom(".ip-address-input").isFocused("focuses the input again");
  });
});
