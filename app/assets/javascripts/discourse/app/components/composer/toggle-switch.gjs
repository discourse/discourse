import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class ComposerToggleSwitch extends Component {
  @action
  mouseDown(event) {
    if (this.args.preventFocus) {
      event.preventDefault();
    }
  }

  get label() {
    const keyboardShortcut = `${translateModKey("ctrl")}+M`;
    if (this.args.state) {
      return i18n("composer.switch_to_markdown", { keyboardShortcut });
    } else {
      return i18n("composer.switch_to_rich_text", { keyboardShortcut });
    }
  }

  <template>
    {{! template-lint-disable no-redundant-role }}
    <button
      class={{concatClass
        "composer-toggle-switch"
        (if @state "--rte" "--markdown")
      }}
      type="button"
      role="switch"
      disabled={{@disabled}}
      aria-checked={{if @state "true" "false"}}
      aria-label={{this.label}}
      title={{this.label}}
      {{! template-lint-disable no-pointer-down-event-binding }}
      {{on "mousedown" this.mouseDown}}
      data-rich-editor={{@state}}
      ...attributes
    >
      <span class="composer-toggle-switch__slider">
        <span
          class={{concatClass
            "composer-toggle-switch__left-icon"
            (unless @state "--active")
          }}
          aria-hidden="true"
        >{{icon "fab-markdown"}}</span>
        <span
          class={{concatClass
            "composer-toggle-switch__right-icon"
            (if @state "--active")
          }}
          aria-hidden="true"
        >{{icon "a"}}</span>
      </span>
    </button>
  </template>
}
