import Component from "@glimmer/component";
import DRadioButton from "discourse/ui-kit/d-radio-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class InstallThemeItem extends Component {
  get classes() {
    return `install-theme-item install-theme-item__${this.args.value}`;
  }

  <template>
    <div class={{this.classes}}>
      <DRadioButton
        @name="install-items"
        @id={{@value}}
        @value={{@value}}
        @selection={{@selection}}
      />
      <label class="radio" for={{@value}}>
        {{#if @showIcon}}
          {{dIcon "plus"}}
        {{/if}}
        {{i18n @label}}
      </label>
      {{dIcon "angle-right"}}
    </div>
  </template>
}
