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

  @action
  handleKeydown(event) {
    // forward events to parent handlers (like roving button bar)
    const result = this.args.onKeydown?.(event);
    if (result) {
      event.preventDefault();
    }
    return result;
  }

  get label() {
    if (this.args.state) {
      return i18n("composer.switch_to_markdown", {
        keyboardShortcut: this.keyboardShortcut,
      });
    } else {
      return i18n("composer.switch_to_rich_text", {
        keyboardShortcut: this.keyboardShortcut,
      });
    }
  }

  get keyboardShortcut() {
    return `${translateModKey("ctrl")} M`;
  }

  get ariaKeyshortcuts() {
    return this.keyboardShortcut.replace(/ /g, "+");
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
      aria-keyshortcuts={{this.ariaKeyshortcuts}}
      title={{this.label}}
      {{! template-lint-disable no-pointer-down-event-binding }}
      {{on "mousedown" this.mouseDown}}
      {{on "keydown" this.handleKeydown}}
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
