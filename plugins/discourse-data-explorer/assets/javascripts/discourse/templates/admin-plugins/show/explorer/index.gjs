import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import PickFilesButton from "discourse/components/pick-files-button";
import TableHeaderToggle from "discourse/components/table-header-toggle";
import TextField from "discourse/components/text-field";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import icon from "discourse/helpers/d-icon";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import ShareReport from "../../../../components/share-report";

export default <template>
  {{#if @controller.disallow}}
    <h1>{{i18n "explorer.admins_only"}}</h1>
  {{else}}
    <div class="discourse-data-explorer-query-list">
      <TextField
        @value={{@controller.search}}
        @placeholderKey="explorer.search_placeholder"
        @onChange={{@controller.updateSearch}}
      />
      <DButton
        @action={{@controller.displayCreate}}
        @icon="plus"
        class="no-text btn-right"
      />
      <PickFilesButton
        @label="explorer.import.label"
        @icon="upload"
        @acceptedFormatsOverride={{@controller.acceptedImportFileTypes}}
        @showButton="true"
        @onFilesPicked={{@controller.import}}
        class="import-btn"
      />
    </div>

    {{#if @controller.showCreate}}
      <div class="query-create">
        <TextField
          @value={{@controller.newQueryName}}
          @placeholderKey="explorer.create_placeholder"
          @onChange={{@controller.updateNewQueryName}}
        />
        <DButton
          @action={{@controller.create}}
          @disabled={{@controller.createDisabled}}
          @label="explorer.create"
          @icon="plus"
        />
      </div>
    {{/if}}

    {{#if @controller.othersDirty}}
      <div class="warning">
        {{icon "triangle-exclamation"}}
        {{i18n "explorer.others_dirty"}}
      </div>
    {{/if}}

    {{#if @controller.model.content.length}}
      <ConditionalLoadingSpinner @condition={{@controller.loading}} />

      <div class="container">
        <table class="d-admin-table recent-queries">
          <thead class="heading-container">
            <th class="col heading name">
              <div
                role="button"
                class="heading-toggle"
                {{on "click" (fn @controller.updateSortProperty "name")}}
              >
                <TableHeaderToggle
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
                {{on "click" (fn @controller.updateSortProperty "username")}}
              >
                <TableHeaderToggle
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
                {{on "click" (fn @controller.updateSortProperty "last_run_at")}}
              >
                <TableHeaderToggle
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
            {{#each @controller.filteredContent as |query|}}
              <tr class="d-admin-row__content query-row">
                <td class="d-admin-row__overview">
                  <LinkTo
                    {{on "click" @controller.scrollTop}}
                    @route="adminPlugins.show.explorer.details"
                    @model={{query.id}}
                  >
                    <b class="query-name">{{query.name}}</b>
                    <span class="query-desc">{{query.description}}</span>
                  </LinkTo>
                </td>
                <td class="d-admin-row__detail query-created-by">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "explorer.query_user"}}
                  </div>
                  {{#if query.username}}
                    <div>
                      <a href="/u/{{query.username}}/activity">
                        <span>{{query.username}}</span>
                      </a>
                    </div>
                  {{/if}}
                </td>
                <td class="d-admin-row__detail query-group-names">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "explorer.query_groups"}}
                  </div>
                  <div class="group-names">
                    {{#each query.group_names as |group|}}
                      <ShareReport @group={{group}} @query={{query}} />
                    {{/each}}
                  </div>
                </td>
                <td class="d-admin-row__detail query-created-at">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "explorer.query_time"}}
                  </div>
                  {{#if query.last_run_at}}
                    <span>
                      {{ageWithTooltip query.last_run_at format="medium"}}
                    </span>
                  {{else if query.created_at}}
                    <span>
                      {{ageWithTooltip query.created_at format="medium"}}
                    </span>
                  {{/if}}
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

      <div class="explorer-pad-bottom"></div>
    {{/if}}
  {{/if}}
</template>
