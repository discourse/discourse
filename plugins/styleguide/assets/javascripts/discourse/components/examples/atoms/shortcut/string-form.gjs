import Component from "@glimmer/component";
import { formatShortcut } from "discourse/lib/shortcut-format";
import DButton from "discourse/ui-kit/d-button";

export default class StringFormExample extends Component {
  shortcut = formatShortcut("mod+enter");

  get title() {
    return `Save (${this.shortcut.label})`;
  }

  <template>
    <DButton
      aria-keyshortcuts={{this.shortcut.aria}}
      class="btn-primary"
      @icon="check"
      @translatedLabel="Save"
      @translatedTitle={{this.title}}
    />
  </template>
}
