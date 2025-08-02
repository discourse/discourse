import { i18n } from "discourse-i18n";

const FKOptional = <template>
  {{#unless @field.required}}
    <span class="form-kit__container-optional">({{i18n
        "form_kit.optional"
      }})</span>
  {{/unless}}
</template>;

export default FKOptional;
