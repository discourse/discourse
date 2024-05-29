import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { i18n } from "discourse-i18n";
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
      <DButton
        class="icon btn-flat"
        aria-expanded={{@active}}
        aria-haspopup="true"
        @translatedTitle={{i18n @title}}
        aria-label={{i18n @title}}
        id={{@iconId}}
        @icon={{@icon}}
        @translatedLabel={{@contents}}
        {{on "click" this.click}}
      />

    </li>
  </template>
}
