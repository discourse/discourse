const FKSection = <template>
  <div class="d-form__section">
    {{#if @title}}
      <h2 class="d-form__section-title">{{@title}}</h2>
    {{/if}}

    {{#if @subtitle}}
      <span class="d-form__section-subtitle">{{@subtitle}}</span>
    {{/if}}

    {{yield}}
  </div>
</template>;

export default FKSection;
