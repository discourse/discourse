import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import AiEmbeddingEditor from "./ai-embedding-editor";

export default class AiEmbeddingsListEditor extends Component {
  @service adminPluginNavManager;

  get hasEmbeddingElements() {
    return this.args.embeddings.content.length !== 0;
  }

  <template>
    <DBreadcrumbsItem
      @label={{i18n "discourse_ai.embeddings.short_title"}}
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-embeddings"
    />
    <section class="ai-embeddings-list-editor admin-detail">
      {{#if @currentEmbedding}}
        <AiEmbeddingEditor
          @embeddings={{@embeddings}}
          @model={{@currentEmbedding}}
        />
      {{else}}
        <DPageSubheader
          @descriptionLabel={{i18n "discourse_ai.embeddings.description"}}
          @learnMoreUrl="https://meta.discourse.org/t/discourse-ai-embeddings/259603"
          @titleLabel={{i18n "discourse_ai.embeddings.short_title"}}
        >
          <:actions as |actions|>
            <actions.Primary
              class="ai-embeddings-list-editor__new-button"
              @icon="plus"
              @label="discourse_ai.embeddings.new"
              @route="adminPlugins.show.discourse-ai-embeddings.new"
            />
          </:actions>
        </DPageSubheader>

        {{#if this.hasEmbeddingElements}}
          <table class="d-table">
            <thead class="d-table__header">
              <tr>
                <th>{{i18n "discourse_ai.embeddings.display_name"}}</th>
                <th>{{i18n "discourse_ai.embeddings.provider"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each @embeddings.content as |embedding|}}
                <tr class="ai-embeddings-list__row d-table__row">
                  <td class="d-table__cell --overview">
                    <div class="ai-embeddings-list__name">
                      <strong>
                        {{embedding.display_name}}
                      </strong>
                    </div>
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "discourse_ai.embeddings.provider"}}
                    </div>
                    {{i18n
                      (concat
                        "discourse_ai.embeddings.providers." embedding.provider
                      )
                    }}
                  </td>
                  <td class="d-table__cell --controls">
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
            @ctaClass="ai-embeddings-list-editor__empty-new-button"
            @ctaLabel="discourse_ai.embeddings.new"
            @ctaRoute="adminPlugins.show.discourse-ai-embeddings.new"
            @emptyLabel="discourse_ai.embeddings.empty"
          />
        {{/if}}
      {{/if}}
    </section>
  </template>
}
