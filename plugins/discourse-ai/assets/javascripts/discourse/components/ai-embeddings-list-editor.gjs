import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import DTooltip from "float-kit/components/d-tooltip";
import AiEmbeddingEditor from "./ai-embedding-editor";

export default class AiEmbeddingsListEditor extends Component {
  @service adminPluginNavManager;

  get hasEmbeddingElements() {
    return this.args.embeddings.length !== 0;
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-embeddings"
      @label={{i18n "discourse_ai.embeddings.short_title"}}
    />
    <section class="ai-embeddings-list-editor admin-detail">
      {{#if @currentEmbedding}}
        <AiEmbeddingEditor
          @model={{@currentEmbedding}}
          @embeddings={{@embeddings}}
        />
      {{else}}
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.embeddings.short_title"}}
          @descriptionLabel={{i18n "discourse_ai.embeddings.description"}}
          @learnMoreUrl="https://meta.discourse.org/t/discourse-ai-embeddings/259603"
        >
          <:actions as |actions|>
            <actions.Primary
              @label="discourse_ai.embeddings.new"
              @route="adminPlugins.show.discourse-ai-embeddings.new"
              @icon="plus"
              class="ai-embeddings-list-editor__new-button"
            />
          </:actions>
        </DPageSubheader>

        {{#if this.hasEmbeddingElements}}
          <table class="d-admin-table">
            <thead>
              <tr>
                <th>{{i18n "discourse_ai.embeddings.display_name"}}</th>
                <th>{{i18n "discourse_ai.embeddings.provider"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each @embeddings as |embedding|}}
                <tr class="ai-embeddings-list__row d-admin-row__content">
                  <td class="d-admin-row__overview">
                    <div class="ai-embeddings-list__name">
                      <strong>
                        {{embedding.display_name}}
                      </strong>
                    </div>
                  </td>
                  <td class="d-admin-row__detail">
                    <div class="d-admin-row__mobile-label">
                      {{i18n "discourse_ai.embeddings.provider"}}
                    </div>
                    {{i18n
                      (concat
                        "discourse_ai.embeddings.providers." embedding.provider
                      )
                    }}
                  </td>
                  <td class="d-admin-row__controls">
                    {{#if embedding.seeded}}
                      <DTooltip
                        class="ai-embeddings-list__edit-disabled-tooltip"
                      >
                        <:trigger>
                          <DButton
                            class="btn btn-default btn-small disabled"
                            @label="discourse_ai.embeddings.edit"
                          />
                        </:trigger>
                        <:content>
                          {{i18n "discourse_ai.embeddings.seeded_warning"}}
                        </:content>
                      </DTooltip>
                    {{else}}
                      <DButton
                        class="btn btn-default btn-small ai-embeddings-list__edit-button"
                        @label="discourse_ai.embeddings.edit"
                        @route="adminPlugins.show.discourse-ai-embeddings.edit"
                        @routeModels={{embedding.id}}
                      />
                    {{/if}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <AdminConfigAreaEmptyList
            @ctaLabel="discourse_ai.embeddings.new"
            @ctaRoute="adminPlugins.show.discourse-ai-embeddings.new"
            @ctaClass="ai-embeddings-list-editor__empty-new-button"
            @emptyLabel="discourse_ai.embeddings.empty"
          />
        {{/if}}
      {{/if}}
    </section>
  </template>
}
