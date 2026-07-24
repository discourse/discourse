import { concat } from "@ember/helper";
import FormText from "discourse/form-kit/components/fk/text";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const FKContainer = <template>
  <div
    class={{dConcatClass
      "form-kit__container"
      @class
      (if @direction (concat "--" @direction))
      (if (eq @format "full") "--full")
    }}
    ...attributes
  >
    {{#if @title}}
      <span class="form-kit__container-title">
        {{@title}}
        {{#if @optional}}
          <span class="form-kit__container-optional">({{i18n
              "form_kit.optional"
            }})</span>
        {{/if}}
      </span>
    {{/if}}

    {{#if @subtitle}}
      <FormText class="form-kit__container-subtitle">{{@subtitle}}</FormText>
    {{/if}}

    <div
      class={{dConcatClass
        "form-kit__container-content"
        (if @format (concat "--" @format))
      }}
    >
      {{yield}}
    </div>
  </div>
</template>;

export default FKContainer;
