import { concat, fn } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import formatDate from "discourse/helpers/format-date";
import { i18n } from "discourse-i18n";
import AdminCreateLeaderboard from "discourse/plugins/discourse-gamification/admin/components/admin-create-leaderboard";

export default RouteTemplate(
  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{@controller.adminPluginNavManager.currentPlugin.name}}/leaderboards"
      @label={{i18n "gamification.leaderboard.title"}}
    />

    <div class="discourse-gamification__leaderboards admin-detail">
      <DPageSubheader @titleLabel={{i18n "gamification.leaderboard.title"}}>
        <:actions as |actions|>
          {{#if @controller.model.leaderboards}}
            <actions.Primary
              @label="gamification.leaderboard.new"
              @title="gamification.leaderboard.new"
              class="leaderboard-admin__btn-new"
              @action={{fn (mut @controller.creatingNew) true}}
            />

            <actions.Default
              @label="gamification.recalculate"
              @title="gamification.recalculate"
              class="leaderboard-admin__btn-recalculate"
              @action={{@controller.recalculateScores}}
            />
          {{/if}}
        </:actions>
      </DPageSubheader>

      {{#if @controller.creatingNew}}
        <AdminCreateLeaderboard @onCancel={{@controller.resetNewLeaderboard}} />
      {{/if}}

      <div class="leaderboards">
        {{#if @controller.model.leaderboards}}
          <table>
            <thead>
              <th>{{i18n "gamification.admin.name"}}</th>
              <th>{{i18n "gamification.admin.period"}}</th>
              <th></th>
            </thead>

            <tbody>
              {{#each @controller.sortedLeaderboards as |leaderboard|}}
                <tr id={{concat "leaderboard-admin__row-" leaderboard.id}}>
                  <td>
                    <LinkTo
                      @route="gamificationLeaderboard.byName"
                      @model={{leaderboard.id}}
                    >
                      {{leaderboard.name}}
                    </LinkTo>
                  </td>
                  <td>
                    {{#if leaderboard.fromDate}}
                      {{formatDate
                        (@controller.parseDate leaderboard.fromDate)
                      }}
                      -
                      {{formatDate (@controller.parseDate leaderboard.toDate)}}
                    {{else}}
                      {{leaderboard.defaultPeriod}}
                    {{/if}}
                  </td>
                  <td style="width: 120px">
                    <div class="leaderboard-admin__listitem-action">
                      <LinkTo
                        @route="adminPlugins.show.discourse-gamification-leaderboards.show"
                        @model={{leaderboard}}
                        class="btn leaderboard-admin__edit btn-text btn-small"
                      >{{i18n "gamification.edit"}} </LinkTo>

                      <DButton
                        class="btn-small leaderboard-admin__delete btn-danger"
                        @icon="trash-can"
                        @title="gamification.delete"
                        @action={{fn
                          @controller.destroyLeaderboard
                          leaderboard
                        }}
                      />
                    </div>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          {{#unless @controller.creatingNew}}
            <div class="admin-plugin-config-area__empty-list">
              {{i18n "gamification.leaderboard.none"}}
              <DButton
                @label="gamification.leaderboard.cta"
                class="btn-default btn-small leaderboard-admin__cta-new"
                @action={{fn (mut @controller.creatingNew) true}}
              />
            </div>
          {{/unless}}
        {{/if}}
      </div>
    </div>
  </template>
);
