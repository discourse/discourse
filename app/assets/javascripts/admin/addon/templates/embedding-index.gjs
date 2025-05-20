import RouteTemplate from "ember-route-template";
import PluginOutlet from "discourse/components/plugin-outlet";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import EmbeddableHost from "admin/components/embeddable-host";
import HighlightedCode from "admin/components/highlighted-code";

export default RouteTemplate(
  <template>
    {{#if @controller.embedding.embeddable_hosts}}
      {{#if @controller.showEmbeddingCode}}
        <AdminConfigAreaCard
          @heading="admin.embedding.configuration_snippet"
          @collapsable={{true}}
          @collapsed={{true}}
          class="admin-embedding-index__code"
        >
          <:content>
            {{htmlSafe (i18n "admin.embedding.sample")}}
            <HighlightedCode @code={{@controller.embeddingCode}} @lang="html" />
          </:content>
        </AdminConfigAreaCard>
      {{/if}}

      <table class="d-admin-table">
        <thead>
          <th>{{i18n "admin.embedding.host"}}</th>
          <th>{{i18n "admin.embedding.allowed_paths"}}</th>
          <th>{{i18n "admin.embedding.category"}}</th>
          <th>{{i18n "admin.embedding.tags"}}</th>
          {{#if @controller.embedding.embed_by_username}}
            <th>{{i18n
                "admin.embedding.post_author_with_default"
                author=@controller.embedding.embed_by_username
              }}</th>
          {{else}}
            <th>{{i18n "admin.embedding.post_author"}}</th>
          {{/if}}
        </thead>
        <tbody>
          {{#each @controller.embedding.embeddable_hosts as |host|}}
            <EmbeddableHost
              @host={{host}}
              @deleteHost={{@controller.deleteHost}}
            />
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
      @outletArgs={{lazyHash embedding=@controller.embedding}}
    />
  </template>
);
