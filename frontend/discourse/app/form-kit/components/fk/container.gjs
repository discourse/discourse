import { concat } from "@ember/helper";
import FormText from "discourse/form-kit/components/fk/text";
import concatClass from "discourse/helpers/concat-class";
import { eq } from "discourse/truth-helpers";

const FKContainer = <template>
  <div
    class={{concatClass
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
      </span>
    {{/if}}

    {{#if @subtitle}}
      <FormText class="form-kit__container-subtitle">{{@subtitle}}</FormText>
    {{/if}}

    <div
      class={{concatClass
        "form-kit__container-content"
        (if @format (concat "--" @format))
      }}
    >
      {{yield}}
    </div>
  </div>
</template>;

export default FKContainer;
