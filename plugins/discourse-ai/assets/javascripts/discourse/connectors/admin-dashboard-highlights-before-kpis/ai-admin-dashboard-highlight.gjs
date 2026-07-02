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

  loadId = 0;

  get queryKey() {
    const { period, startDate, endDate } = this.args.outletArgs;
    return `${period}:${this.formatDate(startDate)}:${this.formatDate(endDate)}`;
  }

  formatDate(value) {
    if (!value) {
      return value;
    }
    const date = moment(value);
    return date.isValid() ? date.format("YYYY-MM-DD") : value;
  }

  @action
  async loadHighlight() {
    const loadId = ++this.loadId;
    this.loading = true;
    this.failed = false;

    const { period, startDate, endDate } = this.args.outletArgs;

    try {
      const result = await ajax(
        "/admin/plugins/discourse-ai/admin-dashboard-highlights.json",
        {
          data: {
            period,
            start_date: this.formatDate(startDate),
            end_date: this.formatDate(endDate),
          },
        }
      );
      if (loadId !== this.loadId) {
        return;
      }
      this.highlight = result.highlight;
    } catch {
      if (loadId !== this.loadId) {
        return;
      }
      this.failed = true;
    } finally {
      if (loadId === this.loadId) {
        this.loading = false;
      }
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
