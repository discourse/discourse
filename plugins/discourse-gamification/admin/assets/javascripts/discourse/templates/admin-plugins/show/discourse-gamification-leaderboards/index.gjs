import { concat, fn } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DMenu from "discourse/float-kit/components/d-menu";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "gamification.leaderboard.title"}}
    @path="/admin/plugins/{{@controller.adminPluginNavManager.currentPlugin.name}}/leaderboards"
  />

  <div class="discourse-gamification__leaderboards admin-detail">
    <DPageSubheader @titleLabel={{i18n "gamification.leaderboard.title"}}>
      <:actions as |actions|>
        {{#if @controller.model.leaderboards}}
          <actions.Primary
            class="leaderboard-admin__btn-new"
            @icon="plus"
            @label="gamification.leaderboard.new"
            @route="adminPlugins.show.discourse-gamification-leaderboards.new"
          />

          <actions.Default
            class="leaderboard-admin__btn-recalculate"
            @action={{@controller.recalculateScores}}
            @label="gamification.recalculate"
          />
        {{/if}}
      </:actions>
    </DPageSubheader>

    <div class="leaderboards">
      {{#if @controller.model.leaderboards}}
        <table class="d-table">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell">{{i18n
                  "gamification.admin.name"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "gamification.admin.created_by"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "gamification.admin.period"
                }}</th>
              <th class="d-table__header-cell"></th>
            </tr>
          </thead>

          <tbody class="d-table__body">
            {{#each @controller.model.leaderboards as |leaderboard|}}
              <tr
                class="d-table__row"
                id={{concat "leaderboard-admin__row-" leaderboard.id}}
              >
                <td class="d-table__cell --overview">
                  <LinkTo
                    class="d-table__overview-link"
                    @model={{leaderboard.id}}
                    @route="adminPlugins.show.discourse-gamification-leaderboards.edit"
                  >
                    <div class="d-table__overview-name">
                      {{leaderboard.name}}
                    </div>
                  </LinkTo>
                </td>
                <td class="d-table__cell --detail leaderboard-admin__creator">
                  <div class="d-table__mobile-label">
                    {{i18n "gamification.admin.created_by"}}
                  </div>
                  {{#if leaderboard.createdBy}}
                    <DUserLink
                      class="leaderboard-admin__creator-link"
                      @user={{leaderboard.createdBy}}
                    >
                      {{dAvatar leaderboard.createdBy imageSize="tiny"}}
                      <span>{{leaderboard.createdBy.username}}</span>
                    </DUserLink>
                  {{/if}}
                </td>
                <td class="d-table__cell --detail">
                  <div class="d-table__mobile-label">
                    {{i18n "gamification.admin.period"}}
                  </div>
                  {{#if leaderboard.fromDate}}
                    {{dFormatDate (@controller.parseDate leaderboard.fromDate)}}
                    -
                    {{dFormatDate (@controller.parseDate leaderboard.toDate)}}
                  {{else}}
                    {{leaderboard.defaultPeriod}}
                  {{/if}}
                </td>
                <td class="d-table__cell --controls">
                  <div class="d-table__cell-actions">
                    <LinkTo
                      class="btn btn-default leaderboard-admin__edit btn-text btn-small"
                      @model={{leaderboard}}
                      @route="adminPlugins.show.discourse-gamification-leaderboards.edit"
                    >{{i18n "gamification.edit"}}</LinkTo>

                    <DMenu
                      @icon="ellipsis-vertical"
                      @identifier="leaderboard-admin-menu"
                      @placement="bottom-end"
                      @title={{i18n "more_options"}}
                      @triggerClass="btn-default btn-small"
                    >
                      <:content as |menu|>
                        <DDropdownMenu as |dropdown|>
                          <dropdown.item>
                            <DButton
                              class="btn-transparent leaderboard-admin__view"
                              @icon="eye"
                              @label="gamification.leaderboard.view"
                              @route="gamificationLeaderboard.byName"
                              @routeModels={{leaderboard.id}}
                            />
                          </dropdown.item>
                          <dropdown.item>
                            <DButton
                              class="btn-transparent --danger leaderboard-admin__delete"
                              @action={{fn
                                @controller.destroyLeaderboard
                                leaderboard
                                menu.close
                              }}
                              @icon="trash-can"
                              @label="gamification.delete"
                            />
                          </dropdown.item>
                        </DDropdownMenu>
                      </:content>
                    </DMenu>
                  </div>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <AdminConfigAreaEmptyList
          @ctaLabel="gamification.leaderboard.cta"
          @ctaRoute="adminPlugins.show.discourse-gamification-leaderboards.new"
          @emptyLabel="gamification.leaderboard.none"
        />
      {{/if}}
    </div>
  </div>
</template>
