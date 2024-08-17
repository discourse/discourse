import FKText from "discourse/form-kit/components/fk/text";

const FKFieldset = <template>
  <fieldset name={{@name}} class="form-kit__fieldset" ...attributes>
    {{#if @title}}
      <legend class="form-kit__fieldset-title">{{@title}}</legend>
    {{/if}}

    {{#if @description}}
      <FKText class="form-kit__fieldset-description">
        {{@description}}
      </FKText>
    {{/if}}

    {{yield}}
  </fieldset>
</template>;

export default FKFieldset;
