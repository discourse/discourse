import RadioButton from "discourse/components/radio-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const InstallThemeItem = <template>
  <div class="install-theme-item">
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
</template>;

export default InstallThemeItem;
