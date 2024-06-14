const FKSection = <template>
  <div class="form-kit__section">
    {{#if @title}}
      <h2 class="form-kit__section-title">{{@title}}</h2>
    {{/if}}

    {{#if @subtitle}}
      <span class="form-kit__section-subtitle">{{@subtitle}}</span>
    {{/if}}

    {{yield}}
  </div>
</template>;

export default FKSection;
