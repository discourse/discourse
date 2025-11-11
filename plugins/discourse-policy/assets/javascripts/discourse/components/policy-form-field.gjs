import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";

const PolicyFormFields = <template>
  <div class="policy-field {{@name}}">
    <div class="policy-field-label">
      <span class="label">
        {{i18n (concat "discourse_policy.builder." @name ".label")}}
        {{#if @required}}
          <span class="required-field">*</span>
        {{/if}}
      </span>
    </div>

    <div class="policy-field-control">
      {{yield}}
    </div>

    <span class="policy-field-description">
      <span class="description">
        {{i18n (concat "discourse_policy.builder." @name ".description")}}
      </span>
    </span>
  </div>
</template>;

export default PolicyFormFields;
