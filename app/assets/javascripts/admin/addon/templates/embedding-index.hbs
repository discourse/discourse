{{#if this.embedding.embeddable_hosts}}
  {{#if this.showEmbeddingCode}}
    <AdminConfigAreaCard
      @heading="admin.embedding.configuration_snippet"
      @collapsable={{true}}
      @collapsed={{true}}
      class="admin-embedding-index__code"
    >
      <:content>
        {{html-safe (i18n "admin.embedding.sample")}}
        <HighlightedCode @code={{this.embeddingCode}} @lang="html" />
      </:content>
    </AdminConfigAreaCard>
  {{/if}}

  <table class="d-admin-table">
    <thead>
      <th>{{i18n "admin.embedding.host"}}</th>
      <th>{{i18n "admin.embedding.allowed_paths"}}</th>
      <th>{{i18n "admin.embedding.category"}}</th>
      <th>{{i18n "admin.embedding.tags"}}</th>
      {{#if this.embedding.embed_by_username}}
        <th>{{i18n
            "admin.embedding.post_author_with_default"
            author=this.embedding.embed_by_username
          }}</th>
      {{else}}
        <th>{{i18n "admin.embedding.post_author"}}</th>
      {{/if}}
    </thead>
    <tbody>
      {{#each this.embedding.embeddable_hosts as |host|}}
        <EmbeddableHost @host={{host}} @deleteHost={{action "deleteHost"}} />
      {{/each}}
    </tbody>
  </table>
{{else}}
  <AdminConfigAreaEmptyList
    @ctaLabel="admin.embedding.add_host"
    @ctaRoute="adminEmbedding.new"
    @ctaClass="admin-embedding__add-host"
    @emptyLabel="admin.embedding.get_started"
  />
{{/if}}

<PluginOutlet
  @name="after-embeddable-hosts-table"
  @outletArgs={{hash embedding=this.embedding}}
/>