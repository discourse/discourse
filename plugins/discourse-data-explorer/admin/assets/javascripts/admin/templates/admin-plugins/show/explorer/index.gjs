import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DMultiSelect from "discourse/ui-kit/d-multi-select";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DPickFilesButton from "discourse/ui-kit/d-pick-files-button";
import DTableHeaderToggle from "discourse/ui-kit/d-table-header-toggle";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";
import ShareReport from "discourse/plugins/discourse-data-explorer/discourse/components/share-report";

export default <template>
  <div class="admin-detail">
    <DPageSubheader @titleLabel={{i18n "explorer.queries"}}>
      <:actions as |actions|>
        <actions.Primary
          @icon="plus"
          @label="explorer.new_query"
          @route="adminPlugins.show.explorer.new"
        />
        <actions.Wrapped>
          <DPickFilesButton
            class="d-page-action-button btn-small"
            @acceptedFormatsOverride={{@controller.acceptedImportFileTypes}}
            @icon="upload"
            @label="explorer.import.label"
            @onFilesPicked={{@controller.import}}
            @showButton="true"
          />
        </actions.Wrapped>
      </:actions>
    </DPageSubheader>

    <DFilterControls
      @additionalFiltersActive={{@controller.hasTagFilter}}
      @array={{@controller.model.content}}
      @initialTextFilter={{@controller.textFilter}}
      @inputPlaceholder={{i18n "explorer.search_placeholder"}}
      @loading={{@controller.searchLoading}}
      @noResultsMessage={{i18n "explorer.no_search_results"}}
      @onResetFilters={{@controller.onResetFilters}}
      @onTextFilterChange={{@controller.onTextFilterChange}}
    >
      <:additionalFilters>
        <DMultiSelect
          class="query-tag-filter"
          @label={{i18n "explorer.filter_by_tag"}}
          @loadFn={{@controller.loadTags}}
          @onChange={{@controller.onTagFilterChange}}
          @selection={{@controller.tagSelection}}
        >
          <:selection as |tag|>{{tag.name}}</:selection>
          <:result as |tag|>{{tag.name}}</:result>
        </DMultiSelect>
      </:additionalFilters>

      <:content as |filteredQueries|>
        {{#if @controller.model.content.length}}
          <DConditionalLoadingSpinner @condition={{@controller.loading}} />

          <DLoadMore @action={{@controller.loadMore}}>
            <div class="container discourse-data-explorer-query-list">
              <table class="d-table recent-queries">
                <thead class="d-table__header">
                  <tr class="d-table__row">
                    <th class="d-table__header-cell">
                      <DTableHeaderToggle
                        @asc={{not @controller.sortDescending}}
                        @automatic={{true}}
                        @field="name"
                        @labelKey="explorer.query_name"
                        @onToggle={{@controller.updateSortProperty}}
                        @order={{@controller.sortByProperty}}
                      />
                    </th>
                    <th class="d-table__header-cell">
                      <DTableHeaderToggle
                        @asc={{not @controller.sortDescending}}
                        @automatic={{true}}
                        @field="username"
                        @labelKey="explorer.query_user"
                        @onToggle={{@controller.updateSortProperty}}
                        @order={{@controller.sortByProperty}}
                      />
                    </th>
                    <th class="d-table__header-cell">
                      {{i18n "explorer.query_groups"}}
                    </th>
                    <th class="d-table__header-cell">
                      <DTableHeaderToggle
                        @asc={{not @controller.sortDescending}}
                        @automatic={{true}}
                        @field="last_run_at"
                        @labelKey="explorer.query_time"
                        @onToggle={{@controller.updateSortProperty}}
                        @order={{@controller.sortByProperty}}
                      />
                    </th>
                  </tr>
                </thead>
                <tbody class="d-table__body">
                  {{#each filteredQueries as |query|}}
                    <tr class="d-table__row query-row">
                      <td class="d-table__cell --overview">
                        <LinkTo
                          class="d-table__overview-link"
                          @model={{query.id}}
                          @route="adminPlugins.show.explorer.edit"
                        >
                          <div
                            class="d-table__overview-name query-name"
                          >{{query.name}}</div>
                          <div
                            class="query-desc"
                            title={{query.description}}
                          >{{query.description}}</div>
                        </LinkTo>
                        {{#if query.tags.length}}
                          <div class="d-table__badges query-tags">
                            {{#each query.tags as |tag|}}
                              <a
                                class="d-table-badge"
                                href={{@controller.tagFilterHref tag}}
                                title={{i18n "explorer.filter_by_this_tag"}}
                                {{on "click" (fn @controller.addTagFilter tag)}}
                              >
                                <span
                                  class="d-table-badge__content"
                                >{{tag}}</span>
                              </a>
                            {{/each}}
                          </div>
                        {{/if}}
                      </td>
                      <td class="d-table__cell --detail query-created-by">
                        <div class="d-table__mobile-label">
                          {{i18n "explorer.query_user"}}
                        </div>
                        {{#if query.user}}
                          <DUserLink
                            class="query-created-by__link"
                            @user={{query.user}}
                          >
                            {{dAvatar query.user imageSize="tiny"}}
                            <span>{{query.user.username}}</span>
                          </DUserLink>
                        {{/if}}
                      </td>
                      <td class="d-table__cell --detail query-group-names">
                        <div class="d-table__mobile-label">
                          {{i18n "explorer.query_groups"}}
                        </div>
                        <div class="group-names">
                          {{#each query.group_names as |group|}}
                            <ShareReport @group={{group}} @query={{query}} />
                          {{/each}}
                          {{#unless query.group_names.length}}
                            -
                          {{/unless}}
                        </div>
                      </td>
                      <td class="d-table__cell --detail query-created-at">
                        <div class="d-table__mobile-label">
                          {{i18n "explorer.query_time"}}
                        </div>
                        {{#if query.last_run_at}}
                          <span>
                            {{dAgeWithTooltip
                              query.last_run_at
                              format="medium"
                            }}
                          </span>
                        {{else if query.created_at}}
                          <span>
                            {{dAgeWithTooltip query.created_at format="medium"}}
                          </span>
                        {{else}}
                          -
                        {{/if}}
                      </td>
                      <td class="d-table__cell --controls">
                        <div class="d-table__cell-actions">
                          <LinkTo
                            class="btn btn-text btn-default btn-small"
                            @model={{query.id}}
                            @route="adminPlugins.show.explorer.edit"
                            {{on "click" @controller.scrollTop}}
                          >
                            {{#if query.is_default}}
                              {{i18n "explorer.view_query"}}
                            {{else}}
                              {{i18n "edit"}}
                            {{/if}}
                          </LinkTo>
                        </div>
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            </div>
          </DLoadMore>

          <DConditionalLoadingSpinner
            @condition={{@controller.model.loadingMore}}
          />
        {{/if}}
      </:content>
    </DFilterControls>
  </div>
</template>
