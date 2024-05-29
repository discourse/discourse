import { Input } from "@ember/component";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

const PreferenceCheckbox = <template>
  <div class={{concatClass "controls" @class}} ...attributes>
    <label class="checkbox-label">
      <Input @type="checkbox" @checked={{@checked}} disabled={{@disabled}} />

      {{#if @labelCount}}
        {{i18n @labelKey count=@labelCount}}
      {{else}}
        {{i18n @labelKey}}
      {{/if}}
    </label>
  </div>
</template>;

export default PreferenceCheckbox;
