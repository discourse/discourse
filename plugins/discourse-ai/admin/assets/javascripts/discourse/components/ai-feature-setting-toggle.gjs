import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import SiteSetting from "discourse/admin/models/site-setting";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";

/**
 * Flips the boolean site setting that enables an AI module or feature.
 *
 * @param {{ name: string, value: boolean }} setting
 * @param {string} label - accessible name for the switch
 * @param {boolean} [disabled]
 * @param {Function} [onChange] - called after a successful save, e.g. to reload the features
 */
export default class AiFeatureSettingToggle extends Component {
  @tracked _pendingValue = null;
  @tracked _savedSetting = null;

  get isSaving() {
    return this._pendingValue !== null;
  }

  get state() {
    return (
      this._pendingValue ??
      (this._savedSetting?.setting === this.args.setting
        ? this._savedSetting.value
        : this.args.setting.value)
    );
  }

  @action
  async toggle() {
    if (this.isSaving || this.args.disabled) {
      return;
    }

    this._pendingValue = !this.state;

    try {
      await SiteSetting.update(this.args.setting.name, this._pendingValue);
      this._savedSetting = {
        setting: this.args.setting,
        value: this._pendingValue,
      };
      await this.args.onChange?.();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this._pendingValue = null;
    }
  }

  <template>
    <DToggleSwitch
      aria-label={{@label}}
      class="ai-feature-setting-toggle"
      data-setting-name={{@setting.name}}
      disabled={{if @disabled true this.isSaving}}
      @state={{this.state}}
      {{on "click" this.toggle}}
    />
  </template>
}
