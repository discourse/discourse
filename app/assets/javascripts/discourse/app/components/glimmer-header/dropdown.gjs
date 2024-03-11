import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import closeOnClickOutside from "../../modifiers/close-on-click-outside";

export default class Dropdown extends Component {
  @action
  click(e) {
    if (wantsNewWindow(e)) {
      return;
    }
    e.preventDefault();
    this.args.onClick(e);

    // remove the focus of the header dropdown button after clicking
    e.target.tagName.toLowerCase() === "button"
      ? e.target.blur()
      : e.target.closest("button").blur();
  }

  <template>
    <li
      class={{concatClass
        @className
        (if @active "active")
        "header-dropdown-toggle"
      }}
      {{(if
        (and @active @targetSelector)
        (modifier
          closeOnClickOutside @onClick (hash targetSelector=@targetSelector)
        )
      )}}
    >
      <button
        class="button icon btn-flat"
        aria-expanded={{@active}}
        aria-haspopup="true"
        href={{@href}}
        data-auto-route="true"
        title={{i18n @title}}
        aria-label={{i18n @title}}
        id={{@iconId}}
        {{on "click" this.click}}
      >
        {{icon @icon}}
        {{@contents}}
      </button>
    </li>
  </template>
}
