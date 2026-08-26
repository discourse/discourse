import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { formatShortcut } from "discourse/lib/shortcut-format";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ComposerToggleSwitch extends Component {
  shortcut = formatShortcut("ctrl+m");

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
        keyboardShortcut: this.shortcut.label,
      });
    } else {
      return i18n("composer.switch_to_rich_text", {
        keyboardShortcut: this.shortcut.label,
      });
    }
  }

  <template>
    {{! eslint-disable ember/template-no-pointer-down-event-binding }}
    <button
      class={{dConcatClass
        "composer-toggle-switch"
        (if @state "--rte" "--markdown")
      }}
      type="button"
      role="switch"
      disabled={{@disabled}}
      aria-checked={{if @state "true" "false"}}
      aria-label={{this.label}}
      aria-keyshortcuts={{this.shortcut.aria}}
      title={{this.label}}
      data-rich-editor={{@state}}
      ...attributes
      {{on "mousedown" this.mouseDown}}
      {{on "keydown" this.handleKeydown}}
    >
      <span class="composer-toggle-switch__slider">
        <span
          class={{dConcatClass
            "composer-toggle-switch__left-icon"
            (unless @state "--active")
          }}
          aria-hidden="true"
        >{{dIcon "fab-markdown"}}</span>
        <span
          class={{dConcatClass
            "composer-toggle-switch__right-icon"
            (if @state "--active")
          }}
          aria-hidden="true"
        >{{dIcon "a"}}</span>
      </span>
    </button>
  </template>
}
