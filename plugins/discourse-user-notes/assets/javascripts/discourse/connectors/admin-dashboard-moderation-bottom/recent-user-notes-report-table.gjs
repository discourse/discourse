import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import AdminReport from "admin/components/admin-report";

@tagName("div")
@classNames(
  "admin-dashboard-moderation-bottom-outlet",
  "recent-user-notes-report-table"
)
export default class RecentUserNotesReportTable extends Component {
  <template>
    {{#if this.siteSettings.user_notes_enabled}}
      <AdminReport @dataSourceName="user_notes" @filters={{this.filters}} />
    {{/if}}
  </template>
}
