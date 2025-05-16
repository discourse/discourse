import { or } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";

const FKSection = <template>
  <div class={{concatClass "form-kit__section" @class}} ...attributes>
    {{#if (or @title @subtitle)}}
      <div class="form-kit__section-header">
        {{#if @title}}
          <h2 class="form-kit__section-title">{{@title}}</h2>
        {{/if}}

        {{#if @subtitle}}
          <span class="form-kit__section-subtitle">{{@subtitle}}</span>
        {{/if}}
      </div>
    {{/if}}

    {{yield}}
  </div>
</template>;

export default FKSection;
