import { concat } from "@ember/helper";
import FormText from "discourse/form-kit/components/fk/text";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const FKContainer = <template>
  <div
    class={{dConcatClass
      "form-kit__container"
      @class
      (if @direction (concat "--" @direction))
    }}
    ...attributes
  >
    {{#if @title}}
      <span class="form-kit__container-title">
        {{@title}}
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
