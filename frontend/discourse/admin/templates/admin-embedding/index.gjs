import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import EmbeddableHost from "discourse/admin/components/embeddable-host";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import DHighlightedCode from "discourse/ui-kit/d-highlighted-code";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.embedding.embeddable_hosts}}
    <div class="admin-embedding-index__full-app-toggle">
      <DToggleSwitch
        aria-label={{i18n "admin.embedding.full_app_mode"}}
        @state={{@controller.fullAppMode}}
        {{on "click" @controller.toggleFullAppMode}}
      />
      <div class="admin-embedding-index__full-app-toggle-text">
        <span class="admin-embedding-index__full-app-toggle-label">
          {{i18n "admin.embedding.full_app_mode"}}
        </span>
        <span class="admin-embedding-index__full-app-toggle-description">
          {{i18n "admin.embedding.full_app_mode_description"}}
        </span>
      </div>
    </div>

    {{#if @controller.showEmbeddingCode}}
      <AdminConfigAreaCard
        class="admin-embedding-index__code"
        @collapsable={{true}}
        @collapsed={{true}}
        @heading="admin.embedding.configuration_snippet"
      >
        <:content>
          {{trustHTML (i18n "admin.embedding.sample")}}
          <DHighlightedCode @code={{@controller.embeddingCode}} @lang="html" />
        </:content>
      </AdminConfigAreaCard>
    {{/if}}

    <table class="d-table">
      <thead class="d-table__header">
        <th class="d-table__header-cell">{{i18n "admin.embedding.host"}}</th>
        <th class="d-table__header-cell">{{i18n
            "admin.embedding.allowed_paths"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "admin.embedding.category"
          }}</th>
        <th class="d-table__header-cell">{{i18n "admin.embedding.tags"}}</th>
        {{#if @controller.embedding.embed_by_username}}
          <th class="d-table__header-cell">{{i18n
              "admin.embedding.post_author_with_default"
              author=@controller.embedding.embed_by_username
            }}</th>
        {{else}}
          <th class="d-table__header-cell">{{i18n
              "admin.embedding.post_author"
            }}</th>
        {{/if}}
      </thead>
      <tbody class="d-table__body">
        {{#each @controller.embedding.embeddable_hosts as |host|}}
          <EmbeddableHost
            @deleteHost={{@controller.deleteHost}}
            @host={{host}}
          />
        {{/each}}
      </tbody>
    </table>
  {{else}}
    <AdminConfigAreaEmptyList
      @ctaClass="admin-embedding__add-host"
      @ctaLabel="admin.embedding.add_host"
      @ctaRoute="adminEmbedding.new"
      @emptyLabel="admin.embedding.get_started"
    />
  {{/if}}

  <PluginOutlet
    @name="after-embeddable-hosts-table"
    @outletArgs={{lazyHash embedding=@controller.embedding}}
  />
</template>
