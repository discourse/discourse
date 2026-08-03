import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type { ComponentLike } from "@glint/template";
import FormUntyped from "discourse/components/form";
import DMenu from "discourse/float-kit/components/d-menu";
import devToolsState from "discourse/static/dev-tools/state";
import { i18n } from "discourse-i18n";

const TOOL_ID = "message-bus";
const DEFAULT_CHANNEL_CAP = 50;
const DEFAULT_GLOBAL_CAP = 500;
const DEFAULT_TRACKED_CHANNELS_CAP = 300;

interface SettingsData {
  maxChannelMessages: number;
  maxGlobalMessages: number;
  maxTrackedChannels: number;
}

// TODO(devxp-typescript-pending): form-kit ships no types; described here as
// the subset this menu invokes. Drop once `discourse/components/form` is typed.
const Form = FormUntyped as unknown as ComponentLike<{
  Element: HTMLFormElement;
  Args: {
    data: SettingsData;
    onSubmit: (data: SettingsData) => void;
  };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  Blocks: { default: [any] };
}>;

export default class SettingsMenu extends Component {
  get channelCap() {
    const value = devToolsState.getFlag(TOOL_ID, "maxChannelMessages");
    return typeof value === "number" ? value : DEFAULT_CHANNEL_CAP;
  }

  get formData(): SettingsData {
    return {
      maxChannelMessages: this.channelCap,
      maxGlobalMessages: this.globalCap,
      maxTrackedChannels: this.trackedChannelsCap,
    };
  }

  get globalCap() {
    const value = devToolsState.getFlag(TOOL_ID, "maxGlobalMessages");
    return typeof value === "number" ? value : DEFAULT_GLOBAL_CAP;
  }

  get trackedChannelsCap() {
    const value = devToolsState.getFlag(TOOL_ID, "maxTrackedChannels");
    return typeof value === "number" ? value : DEFAULT_TRACKED_CHANNELS_CAP;
  }

  @action
  apply(data: SettingsData) {
    devToolsState.setFlag(
      TOOL_ID,
      "maxChannelMessages",
      data.maxChannelMessages
    );
    devToolsState.setFlag(TOOL_ID, "maxGlobalMessages", data.maxGlobalMessages);
    devToolsState.setFlag(
      TOOL_ID,
      "maxTrackedChannels",
      data.maxTrackedChannels
    );
  }

  @action
  reset() {
    devToolsState.setFlag(TOOL_ID, "maxChannelMessages", undefined);
    devToolsState.setFlag(TOOL_ID, "maxGlobalMessages", undefined);
    devToolsState.setFlag(TOOL_ID, "maxTrackedChannels", undefined);
  }

  <template>
    <DMenu
      @identifier="message-bus-settings"
      @icon="gear"
      @modalForMobile={{false}}
      @title={{i18n "dev_tools.message_bus.settings"}}
      @ariaLabel={{i18n "dev_tools.message_bus.settings"}}
      @triggerClass="dev-tools-message-bus__settings-trigger dev-tools-message-bus__action"
    >
      <:content>
        <Form
          @data={{this.formData}}
          @onSubmit={{this.apply}}
          class="dev-tools-message-bus__settings"
          as |form|
        >
          <form.Field
            @name="maxChannelMessages"
            @type="input-number"
            @title={{i18n "dev_tools.message_bus.per_channel_cap"}}
            @validation="required|integer|between:10,2000"
            as |field|
          >
            <field.Control class="dev-tools-message-bus__cap-channel" />
          </form.Field>
          <form.Field
            @name="maxGlobalMessages"
            @type="input-number"
            @title={{i18n "dev_tools.message_bus.global_cap"}}
            @validation="required|integer|between:10,10000"
            as |field|
          >
            <field.Control class="dev-tools-message-bus__cap-global" />
          </form.Field>
          <form.Field
            @name="maxTrackedChannels"
            @type="input-number"
            @title={{i18n "dev_tools.message_bus.tracked_channels_cap"}}
            @validation="required|integer|between:50,2000"
            as |field|
          >
            <field.Control class="dev-tools-message-bus__cap-tracked" />
          </form.Field>
          <form.Actions>
            <button
              type="button"
              class="btn btn-default dev-tools-message-bus__settings-reset"
              {{on "click" this.reset}}
            >
              {{i18n "dev_tools.message_bus.reset"}}
            </button>
            <form.Submit @label="dev_tools.message_bus.apply" />
          </form.Actions>
        </Form>
      </:content>
    </DMenu>
  </template>
}
