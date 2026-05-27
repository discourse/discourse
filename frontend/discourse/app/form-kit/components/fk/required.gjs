import { i18n } from "discourse-i18n";

const FKRequired = <template>
  {{#if @field.required}}
    <span class="form-kit__container-required">({{i18n
        "form_kit.required"
      }})</span>
  {{/if}}
</template>;

export default FKRequired;
