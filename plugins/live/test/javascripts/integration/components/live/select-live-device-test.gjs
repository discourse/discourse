import { tracked } from "@glimmer/tracking";
import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";
import SelectLiveDevice from "discourse/plugins/live/discourse/components/live/select-live-device";

const SELECT = ".test-device-select";
const SYSTEM_DEFAULT = { id: "system_default", name: "System default" };
const DESK_MIC = { id: "desk-mic", name: "Desk mic" };

module("Integration | Component | Live | SelectLiveDevice", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const devices = (this.devices = tracked([SYSTEM_DEFAULT, DESK_MIC]));
    const held = (this.held = tracked("desk-mic"));
    const picks = (this.picks = []);
    const onChange = (deviceId) => {
      picks.push(deviceId);
      held.value = deviceId;
    };

    this.renderSelect = () =>
      render(
        <template>
          <SelectLiveDevice
            class="test-device-select"
            @devices={{devices.value}}
            @kind="audioinput"
            @onChange={{onChange}}
            @value={{held.value}}
          />
        </template>
      );
  });

  test("lists the devices as loading until they are listed", async function (assert) {
    const listing = Promise.withResolvers();
    this.devices.value = listing.promise;

    // Rendering and opening settle only once the devices are listed, so neither is awaited
    // until they are.
    const rendered = this.renderSelect();
    await waitFor(SELECT);
    const opened = dSelect(SELECT).open();
    await waitFor(".d-select__skeleton");

    assert
      .dom(".d-select__empty")
      .doesNotExist("an unanswered device list never reads as empty");

    listing.resolve([SYSTEM_DEFAULT, DESK_MIC]);
    await Promise.all([rendered, opened]);
    await settled();

    assert
      .dSelect(SELECT)
      .hasOptions(["system_default", "desk-mic"], "the devices are listed");
  });

  test("shows a placeholder for the held device until the devices are listed", async function (assert) {
    const listing = Promise.withResolvers();
    this.devices.value = listing.promise;

    const rendered = this.renderSelect();
    await waitFor(`${SELECT} .d-skeleton`);

    assert
      .dom(`${SELECT} .d-skeleton`)
      .exists("the trigger waits instead of showing the raw device id");

    listing.resolve([SYSTEM_DEFAULT, DESK_MIC]);
    await rendered;
    await settled();

    assert.dSelect(SELECT).hasName("Desk mic", "the held device is named");
    assert
      .dom(`${SELECT} .d-pill`)
      .doesNotExist("a listed device is not marked unavailable");
  });

  test("names a held device that was never listed as unknown", async function (assert) {
    this.held.value = "unplugged-mic";
    await this.renderSelect();

    assert
      .dSelect(SELECT)
      .hasName(
        i18n("live.devices.missing_device"),
        "a device the browser never named reads as unknown"
      );
    assert
      .dom(`${SELECT} .d-pill`)
      .hasText(
        i18n("live.devices.unavailable"),
        "the trigger marks it unavailable"
      );
  });

  test("keeps the held device's name when it stops being listed", async function (assert) {
    await this.renderSelect();

    this.devices.value = [SYSTEM_DEFAULT];
    await settled();

    assert.dSelect(SELECT).hasName("Desk mic", "the device keeps its name");
    assert
      .dom(`${SELECT} .d-pill`)
      .hasText(
        i18n("live.devices.unavailable"),
        "the trigger marks it unavailable"
      );
  });

  test("lists a held device that isn't listed as a disabled option", async function (assert) {
    this.held.value = "unplugged-mic";
    await this.renderSelect();

    await dSelect(SELECT).open();

    assert
      .dSelect(SELECT)
      .hasOptions(
        ["system_default", "desk-mic", "unplugged-mic"],
        "the missing device comes after the listed ones"
      );
    assert
      .dSelect(SELECT)
      .hasDisabledOption("unplugged-mic", "it can't be picked again");
    assert
      .dSelect(SELECT)
      .hasSelectedOption("unplugged-mic", "it is still the held device");
    assert
      .dom(".d-select__option[data-value='unplugged-mic'] .d-pill")
      .hasText(
        i18n("live.devices.unavailable"),
        "its row is marked unavailable"
      );
    assert
      .dom(".d-select__option[data-value='desk-mic'] .d-pill")
      .doesNotExist("a listed row is not");
  });

  test("checks the held device in the list", async function (assert) {
    await this.renderSelect();

    await dSelect(SELECT).open();

    assert
      .dom(
        ".d-select__option.--selected[data-value='desk-mic'] .d-select__option-selected-icon.d-icon-check"
      )
      .exists("the held device's row shows a check");
  });

  test("follows the device list while it is open", async function (assert) {
    await this.renderSelect();
    await dSelect(SELECT).open();

    this.devices.value = [
      ...this.devices.value,
      { id: "headset", name: "Headset" },
    ];
    await settled();

    assert
      .dSelect(SELECT)
      .hasOptions(
        ["system_default", "desk-mic", "headset"],
        "a newly listed device joins the open list"
      );
  });

  test("hands a picked device to @onChange", async function (assert) {
    this.held.value = "system_default";
    await this.renderSelect();

    await dSelect(SELECT).open();
    await dSelect(SELECT).select("desk-mic");

    assert.deepEqual(this.picks, ["desk-mic"], "the pick is handed over");
  });
});
