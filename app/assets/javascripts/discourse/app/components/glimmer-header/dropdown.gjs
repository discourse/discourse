import { wantsNewWindow } from "discourse/lib/intercept-click";
import Component from "@glimmer/component";
import i18n from "discourse-common/helpers/i18n";
import concatClass from "discourse/helpers/concat-class";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import dIcon from "discourse-common/helpers/d-icon";
import { modifier } from "ember-modifier";
import { hash } from "@ember/helper";
import CloseOnClickOutside from "../../modifiers/close-on-click-outside";
import and from "truth-helpers/helpers/and";

export default class Dropdown extends Component {
  @action
  click(e) {
    if (wantsNewWindow(e)) {
      return;
    }
    e.preventDefault();
    this.args.onClick(e);
  }

  <template>
    <li
      class={{concatClass
        @className
        (if @active "active")
        "header-dropdown-toggle"
      }}
      {{on "click" this.click}}
      {{(if
        (and @active @targetSelector)
        (modifier
          CloseOnClickOutside @onClick (hash targetSelector=@targetSelector)
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
      >
        {{dIcon @icon}}
        {{@contents}}
      </button>
    </li>
  </template>
}
