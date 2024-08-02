import FKText from "discourse/form-kit/components/fk/text";

const FKFieldset = <template>
  <fieldset class="form-kit__fieldset" ...attributes>
    {{#if @title}}
      <legend class="form-kit__fieldset-title">{{@title}}</legend>
    {{/if}}

    {{#if @subtitle}}
      <FKText class="form-kit__fieldset-subtitle">
        {{@subtitle}}
      </FKText>
    {{/if}}

    {{yield}}
  </fieldset>
</template>;

export default FKFieldset;
