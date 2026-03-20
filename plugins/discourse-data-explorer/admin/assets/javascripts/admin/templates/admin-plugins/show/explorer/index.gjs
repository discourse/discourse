import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import AdminFilterControls from "discourse/admin/components/admin-filter-controls";
import Form from "discourse/components/form";
import { not } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DPickFilesButton from "discourse/ui-kit/d-pick-files-button";
import DTableHeaderToggle from "discourse/ui-kit/d-table-header-toggle";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ShareReport from "discourse/plugins/discourse-data-explorer/discourse/components/share-report";

export default <template>
  <div class="admin-detail">
    {{#if @controller.disallow}}
      <h1>{{i18n "explorer.admins_only"}}</h1>
    {{else}}
      <DPageSubheader @titleLabel={{i18n "explorer.queries"}}>
        <:actions as |actions|>
          <actions.Primary
            @action={{@controller.displayCreate}}
            @icon="plus"
            @label="explorer.create"
          />
          <actions.Wrapped>
            <DPickFilesButton
              @label="explorer.import.label"
              @icon="upload"
              @acceptedFormatsOverride={{@controller.acceptedImportFileTypes}}
              @showButton="true"
              @onFilesPicked={{@controller.import}}
              class="d-page-action-button btn-small"
            />
          </actions.Wrapped>
        </:actions>
      </DPageSubheader>

      <AdminFilterControls
        @array={{@controller.model.content}}
        @inputPlaceholder={{i18n "explorer.search_placeholder"}}
        @noResultsMessage={{i18n "explorer.no_search_results"}}
        @onTextFilterChange={{@controller.onTextFilterChange}}
        @onResetFilters={{@controller.onResetFilters}}
        @loading={{@controller.searchLoading}}
      >
        <:aboveFilters>
          {{#if @controller.showCreate}}
            <div class="query-create">
              <Form
                @data={{@controller.createFormData}}
                @onSubmit={{@controller.create}}
                as |form|
              >
                <form.Field
                  @name="name"
                  @title={{i18n "explorer.create_placeholder"}}
                  @validation="required"
                  @format="large"
                  @type="input"
                  as |field|
                >
                  <field.Control />
                </form.Field>
                <form.Actions>
                  <form.Submit @label="explorer.create" @icon="plus" />
                  <form.Button
                    @action={{@controller.hideCreate}}
                    class="btn-default"
                  >
                    {{i18n "cancel"}}
                  </form.Button>
                </form.Actions>
              </Form>
            </div>
          {{/if}}

          {{#if @controller.othersDirty}}
            <div class="warning">
              {{dIcon "triangle-exclamation"}}
              {{i18n "explorer.others_dirty"}}
            </div>
          {{/if}}
        </:aboveFilters>

        <:content as |filteredQueries|>
          {{#if @controller.model.content.length}}
            <DConditionalLoadingSpinner @condition={{@controller.loading}} />

            <DLoadMore @action={{@controller.loadMore}}>
              <div class="container discourse-data-explorer-query-list">
                <table class="d-table recent-queries">
                  <thead class="d-table__header heading-container">
                    <th class="col heading name">
                      <div
                        role="button"
                        class="heading-toggle"
                        {{on
                          "click"
                          (fn @controller.updateSortProperty "name")
                        }}
                      >
                        <DTableHeaderToggle
                          @field="name"
                          @labelKey="explorer.query_name"
                          @order={{@controller.order}}
                          @asc={{not @controller.sortDescending}}
                          @automatic="true"
                        />
                      </div>
                    </th>
                    <th class="col heading created-by">
                      <div
                        role="button"
                        class="heading-toggle"
                        {{on
                          "click"
                          (fn @controller.updateSortProperty "username")
                        }}
                      >
                        <DTableHeaderToggle
                          @field="username"
                          @labelKey="explorer.query_user"
                          @order={{@controller.order}}
                          @asc={{not @controller.sortDescending}}
                          @automatic="true"
                        />
                      </div>
                    </th>
                    <th class="col heading group-names">
                      <div class="group-names-header">
                        {{i18n "explorer.query_groups"}}
                      </div>
                    </th>
                    <th class="col heading created-at">
                      <div
                        role="button"
                        class="heading-toggle"
                        {{on
                          "click"
                          (fn @controller.updateSortProperty "last_run_at")
                        }}
                      >
                        <DTableHeaderToggle
                          @field="last_run_at"
                          @labelKey="explorer.query_time"
                          @order={{@controller.order}}
                          @asc={{not @controller.sortDescending}}
                          @automatic="true"
                        />
                      </div>
                    </th>
                  </thead>
                  <tbody>
                    {{#each filteredQueries as |query|}}
                      <tr class="d-table__row query-row">
                        <td class="d-table__cell --overview">
                          <LinkTo
                            class="d-table__overview-link"
                            @route="adminPlugins.show.explorer.details"
                            @model={{query.id}}
                          >
                            <div
                              class="d-table__overview-name query-name"
                            >{{query.name}}
                              {{#if query.is_default}}
                                <span class="query-badge">{{i18n
                                    "explorer.default_query"
                                  }}</span>
                              {{/if}}
                            </div>
                            <div class="query-desc">{{query.description}}</div>
                          </LinkTo>
                        </td>
                        <td class="d-table__cell --detail query-created-by">
                          <div class="d-table__mobile-label">
                            {{i18n "explorer.query_user"}}
                          </div>
                          {{#if query.username}}
                            <div>
                              <LinkTo
                                @route="user.summary"
                                @model={{query.username}}
                              >
                                {{query.username}}
                              </LinkTo>
                            </div>
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
                              {{dAgeWithTooltip
                                query.created_at
                                format="medium"
                              }}
                            </span>
                          {{else}}
                            -
                          {{/if}}
                        </td>
                        <td class="d-table__cell-controls">
                          <div class="d-table__cell-actions">
                            <LinkTo
                              {{on "click" @controller.scrollTop}}
                              @route="adminPlugins.show.explorer.details"
                              @model={{query.id}}
                              class="btn btn-default btn-small"
                            >
                              {{i18n "edit"}}
                            </LinkTo>
                          </div>

                        </td>
                      </tr>
                    {{else}}
                      <br />
                      <em class="no-search-results">
                        {{i18n "explorer.no_search_results"}}
                      </em>
                    {{/each}}
                  </tbody>
                </table>
              </div>
            </DLoadMore>

            <DConditionalLoadingSpinner
              @condition={{@controller.model.loadingMore}}
            />

            <div class="explorer-pad-bottom"></div>
          {{/if}}
        </:content>
      </AdminFilterControls>
    {{/if}}
  </div>
</template>
