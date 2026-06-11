import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { ajax } from "discourse/lib/ajax";

export default class AiAdminDashboardHighlight extends Component {
  static shouldRender(args, { siteSettings }) {
    return siteSettings.ai_admin_dashboard_enabled;
  }

  @tracked highlight = null;
  @tracked loading = true;
  @tracked failed = false;

  get queryKey() {
    const { period, startDate, endDate } = this.args.outletArgs;
    return `${period}:${startDate}:${endDate}`;
  }

  isoDate(value) {
    if (!value) {
      return value;
    }
    const date = value instanceof Date ? value : new Date(value);
    return isNaN(date) ? value : date.toISOString().slice(0, 10);
  }

  @action
  async loadHighlight() {
    this.loading = true;
    this.failed = false;

    const { period, startDate, endDate } = this.args.outletArgs;

    try {
      const result = await ajax(
        "/admin/plugins/discourse-ai/admin-dashboard-highlights.json",
        {
          data: {
            period,
            start_date: this.isoDate(startDate),
            end_date: this.isoDate(endDate),
          },
        }
      );
      this.highlight = result.highlight;
    } catch {
      this.failed = true;
    } finally {
      this.loading = false;
    }
  }

  <template>
    {{#unless this.failed}}
      <div
        class="ai-admin-dashboard-highlight"
        aria-live="polite"
        {{didInsert this.loadHighlight}}
        {{didUpdate this.loadHighlight this.queryKey}}
      >
        {{#if this.loading}}
          <div
            class="ai-admin-dashboard-highlight__loading"
            aria-hidden="true"
          ></div>
        {{else if this.highlight}}
          <p class="ai-admin-dashboard-highlight__text">{{this.highlight}}</p>
        {{/if}}
      </div>
    {{/unless}}
  </template>
}
