import Component from "@glimmer/component";
import DashboardPeriodSelector from "discourse/admin/components/dashboard-period-selector";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";
import LiveLivekitStatus from "discourse/plugins/live/admin/components/live-livekit-status";

function formatDuration(seconds) {
  if (!seconds || seconds <= 0) {
    return "0m";
  }

  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);

  if (h > 0) {
    return `${h}h ${m}m`;
  }
  return `${m}m`;
}

export default class LiveDashboard extends Component {
  get overview() {
    return this.args.model?.overview;
  }

  get rooms() {
    return this.args.model?.rooms || [];
  }

  get users() {
    return this.args.model?.users || [];
  }

  get hasData() {
    return this.overview?.total_sessions > 0;
  }

  <template>
    <section class="live-dashboard">
      <div class="live-dashboard__header">
        <h2>{{i18n "live.admin.dashboard.overview"}}</h2>
        <DashboardPeriodSelector
          @endDate={{@controller.endDate}}
          @period={{@controller.period}}
          @setCustomDateRange={{@controller.setCustomDateRange}}
          @setPeriod={{@controller.setPeriod}}
          @startDate={{@controller.startDate}}
        />
      </div>

      {{#if this.hasData}}
        <div class="live-dashboard__stats-cards">
          <div class="live-dashboard__card">
            <span
              class="live-dashboard__card-value"
            >{{this.overview.total_sessions}}</span>
            <span class="live-dashboard__card-label">{{i18n
                "live.admin.dashboard.total_sessions"
              }}</span>
          </div>
          <div class="live-dashboard__card">
            <span
              class="live-dashboard__card-value"
            >{{this.overview.unique_users}}</span>
            <span class="live-dashboard__card-label">{{i18n
                "live.admin.dashboard.unique_users"
              }}</span>
          </div>
          <div class="live-dashboard__card">
            <span class="live-dashboard__card-value">{{formatDuration
                this.overview.avg_duration
              }}</span>
            <span class="live-dashboard__card-label">{{i18n
                "live.admin.dashboard.avg_duration"
              }}</span>
          </div>
        </div>

        {{#if this.rooms.length}}
          <h3>{{i18n "live.admin.dashboard.top_rooms"}}</h3>
          <table class="d-table live-dashboard__rooms-table">
            <thead class="d-table__header">
              <tr>
                <th class="d-table__header-cell">{{i18n
                    "live.admin.dashboard.room_name"
                  }}</th>
                <th class="d-table__header-cell">{{i18n
                    "live.admin.dashboard.unique_users"
                  }}</th>
                <th class="d-table__header-cell">{{i18n
                    "live.admin.dashboard.total_time"
                  }}</th>
              </tr>
            </thead>
            <tbody>
              {{#each this.rooms as |room|}}
                <tr class="d-table__row">
                  <td class="d-table__cell --overview">
                    {{#if room.room_name}}
                      {{room.room_name}}
                    {{else}}
                      {{i18n "live.admin.dashboard.deleted_room"}}
                    {{/if}}
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "live.admin.dashboard.unique_users"}}
                    </div>
                    {{room.unique_users}}
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "live.admin.dashboard.total_time"}}
                    </div>
                    {{formatDuration room.total_seconds}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{/if}}

        {{#if this.users.length}}
          <h3>{{i18n "live.admin.dashboard.top_users"}}</h3>
          <table class="d-table live-dashboard__users-table">
            <thead class="d-table__header">
              <tr>
                <th class="d-table__header-cell">{{i18n
                    "live.admin.dashboard.user"
                  }}</th>
                <th class="d-table__header-cell">{{i18n
                    "live.admin.dashboard.sessions"
                  }}</th>
                <th class="d-table__header-cell">{{i18n
                    "live.admin.dashboard.total_time"
                  }}</th>
              </tr>
            </thead>
            <tbody>
              {{#each this.users as |u|}}
                <tr class="d-table__row">
                  <td class="d-table__cell --overview">
                    {{#if u.username}}
                      <a
                        class="live-dashboard__user-cell"
                        data-user-card={{u.username}}
                        href="/admin/users/{{u.user_id}}/{{u.username}}"
                      >
                        {{dAvatar u imageSize="small"}}
                        <span>{{u.username}}</span>
                      </a>
                    {{else}}
                      {{i18n "live.admin.dashboard.deleted_user"}}
                    {{/if}}
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "live.admin.dashboard.sessions"}}
                    </div>
                    {{u.session_count}}
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "live.admin.dashboard.total_time"}}
                    </div>
                    {{formatDuration u.total_seconds}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{/if}}
      {{else}}
        <p class="live-dashboard__empty">{{i18n
            "live.admin.dashboard.no_data"
          }}</p>
      {{/if}}

      <LiveLivekitStatus />
    </section>
  </template>
}
