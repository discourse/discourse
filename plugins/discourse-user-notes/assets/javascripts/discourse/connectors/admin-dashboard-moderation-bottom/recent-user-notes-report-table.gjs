import Component from "@glimmer/component";
import { service } from "@ember/service";
import AdminReport from "discourse/admin/components/admin-report";

export default class RecentUserNotesReportTable extends Component {
  @service siteSettings;

  <template>
    <div
      class="admin-dashboard-moderation-bottom-outlet recent-user-notes-report-table"
    >
      {{#if this.siteSettings.user_notes_enabled}}
        <AdminReport @dataSourceName="user_notes" @filters={{@filters}} />
      {{/if}}
    </div>
  </template>
}
