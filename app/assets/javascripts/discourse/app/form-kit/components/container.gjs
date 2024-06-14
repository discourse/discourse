import FormText from "discourse/form-kit/components/text";

const FKContainer = <template>
  <div class="form-kit__container" ...attributes>
    {{#if @title}}
      <span class="form-kit__container-title">
        {{@title}}
      </span>
    {{/if}}

    {{#if @subtitle}}
      <FormText class="form-kit__container-subtitle">{{@subtitle}}</FormText>
    {{/if}}

    <div class="form-kit__container-content">
      {{yield}}
    </div>
  </div>
</template>;

export default FKContainer;
