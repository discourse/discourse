import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DPill from "discourse/ui-kit/d-pill";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import { rememberedDeviceName } from "../../lib/live/media-devices.js";

/** A device's name, with a pill saying why the device can't be used when it can't. */
const LiveDeviceName = <template>
  <span class="live-device-name">
    <span class="live-device-name__text">
      {{~@name~}}
    </span>
    {{#if @pill}}
      <DPill @label={{@pill}} />
    {{/if}}
  </span>
</template>;

/**
 * Picks one media device of a kind. A held device the browser no longer lists keeps its name,
 * is marked unavailable, and stays in the list as a disabled option.
 *
 * Args:
 * - `@kind`: `"audioinput"`, `"audiooutput"` or `"videoinput"`, for the name saved when the
 *   held device was last listed.
 * - `@devices`: the listed `{ id, name }` devices, or a promise of them until the first listing,
 *   so the select shows loading rather than an empty list.
 * - `@value`: the held device id.
 * - `@withheld`: whether the browser withheld the devices for lack of permission, so a missing
 *   held device is marked as blocked rather than unavailable.
 * - `@onChange`: called with the picked device id.
 * - `@ariaLabelledBy`: the id of the field's label, or
 * - `@caption`: a caption drawn in the trigger that names the field instead.
 * - `@icon` and `@menuItem`: passed to the select, for one that sits in a menu.
 */
export default class SelectLiveDevice extends Component {
  /** Why a held device that isn't listed can't be used. */
  get missingLabel() {
    return this.args.withheld
      ? i18n("live.devices.no_permission")
      : i18n("live.devices.unavailable");
  }

  @action
  load() {
    return this.#whenListed((devices) => this.#optionsOf(devices));
  }

  @action
  resolve(deviceId) {
    return this.#whenListed((devices) =>
      devices.find((device) => device.id === deviceId)
    );
  }

  @action
  missingDevice(deviceId) {
    return {
      id: deviceId,
      name:
        rememberedDeviceName(this.args.kind, deviceId) ??
        i18n("live.devices.missing_device"),
    };
  }

  @action
  isUnavailable(deviceId) {
    const devices = this.args.devices;
    return (
      Array.isArray(devices) &&
      !devices.some((device) => device.id === deviceId)
    );
  }

  /** Runs `fn` on the listed devices, waiting for the first listing when it hasn't happened. */
  #whenListed(fn) {
    const devices = this.args.devices;
    return Array.isArray(devices)
      ? fn(devices)
      : Promise.resolve(devices).then(fn);
  }

  /** The listed devices, then the held one as a disabled option when the browser no longer lists it. */
  #optionsOf(devices) {
    const heldId = this.args.value;
    if (devices.some((device) => device.id === heldId)) {
      return devices;
    }
    return [
      ...devices,
      selectOption(this.missingDevice(heldId), { disabled: true }),
    ];
  }

  <template>
    <DSelect
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @clearMode="never"
      @createUnresolvedRecord={{this.missingDevice}}
      @icon={{@icon}}
      @load={{this.load}}
      @loadContext={{hash devices=@devices held=@value}}
      @menuItem={{@menuItem}}
      @onChange={{@onChange}}
      @resolveValue={{this.resolve}}
      @selectedIcon="check"
      @skeletonCount={{3}}
      @texts={{hash caption=@caption}}
      @value={{@value}}
      @variant="static"
    >
      <:option as |option|>
        <LiveDeviceName
          @name={{option.label}}
          @pill={{if (this.isUnavailable option.value) this.missingLabel}}
        />
      </:option>
      <:selection as |option|>
        <LiveDeviceName
          @name={{option.label}}
          @pill={{if (this.isUnavailable option.value) this.missingLabel}}
        />
      </:selection>
      <:unresolved as |option|>
        <LiveDeviceName @name={{option.label}} @pill={{this.missingLabel}} />
      </:unresolved>
    </DSelect>
  </template>
}
