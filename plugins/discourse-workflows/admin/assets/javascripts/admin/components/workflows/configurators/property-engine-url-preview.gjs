import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class PropertyEngineUrlPreview extends Component {
  @tracked copied = false;

  get displayPath() {
    const value = this.args.configuration?.path || "";

    if (typeof value === "string" && value.startsWith("=")) {
      return "<expression>";
    }

    return value || "<path>";
  }

  get previewUrl() {
    const uuid = this.args.configuration?.uuid;
    if (uuid) {
      return getAbsoluteURL(`/workflows/form/${uuid}`);
    }

    return getAbsoluteURL(`/workflows/webhooks/${this.displayPath}`);
  }

  get hint() {
    if (this.args.configuration?.uuid !== undefined) {
      return i18n("discourse_workflows.form.save_for_url");
    }

    return null;
  }

  get hasUrl() {
    if (this.args.configuration?.uuid !== undefined) {
      return !!this.args.configuration.uuid;
    }

    return true;
  }

  @action
  async copy() {
    await clipboardCopy(this.previewUrl);
    this.copied = true;
    setTimeout(() => (this.copied = false), 2000);
  }

  <template>
    {{#if this.hasUrl}}
      {{! template-lint-disable no-invalid-interactive }}
      <div
        class="workflows-url-preview {{if this.copied '--copied'}}"
        title={{i18n "discourse_workflows.webhook.click_to_copy"}}
        {{on "click" this.copy}}
      >
        <code>{{this.previewUrl}}</code>
        {{icon (if this.copied "check" "copy")}}
      </div>
    {{else if this.hint}}
      <p class="workflows-url-preview__hint">{{this.hint}}</p>
    {{/if}}
  </template>
}
