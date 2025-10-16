import Component from "@glimmer/component";
import RadioButton from "discourse/components/radio-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class InstallThemeItem extends Component {
  get classes() {
    return `install-theme-item install-theme-item__${this.args.value}`;
  }

  <template>
    <div class={{this.classes}}>
      <RadioButton
        @name="install-items"
        @id={{@value}}
        @value={{@value}}
        @selection={{@selection}}
      />
      <label class="radio" for={{@value}}>
        {{#if @showIcon}}
          {{icon "plus"}}
        {{/if}}
        {{i18n @label}}
      </label>
      {{icon "caret-right"}}
    </div>
  </template>
}
