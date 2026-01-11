import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import concatClass from "discourse/helpers/concat-class";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class CopyButton extends Component {
  @service toasts;

  @tracked copyIcon = "lucide-copy";

  @action
  async copyToClipboard() {
    try {
      await clipboardCopy(String(this.args.value));
      this.copyIcon = "check";
      this.toasts.success({
        duration: 2000,
        data: { message: i18n("copy_codeblock.copied") },
      });
      setTimeout(() => (this.copyIcon = "lucide-check"), 1500);
    } catch (error) {
      console.error("Error copying to clipboard:", error);
      this.toasts.error({
        duration: 3000,
        data: { message: i18n("user.copy_to_clipboard_error") },
      });
    }
  }

  <template>
    <button
      type="button"
      class={{concatClass "copy-button" }}
      title={{i18n (themePrefix "route_inspector.copy_to_clipboard")}}
      {{on "click" this.copyToClipboard}}
    >
      {{icon this.copyIcon}}
    </button>
  </template>
}
