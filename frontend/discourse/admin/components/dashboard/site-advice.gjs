import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { compare } from "@ember/utils";
import linkifySettingLinks from "discourse/admin/modifiers/linkify-setting-links";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DashboardSiteAdvice extends Component {
  @service currentUser;

  @tracked refreshing = false;
  @tracked ignoringId = null;

  @action
  async refresh() {
    this.refreshing = true;
    try {
      await this.args.onRefresh();
    } finally {
      this.refreshing = false;
    }
  }

  @action
  async ignore(problem) {
    this.ignoringId = problem.id;
    try {
      await this.args.onIgnore(problem);
    } finally {
      this.ignoringId = null;
    }
  }

  get sortedProblems() {
    return [...this.args.problems].sort(
      (a, b) => compare(a?.priority, b?.priority) || compare(a?.id, b?.id)
    );
  }

  get title() {
    return i18n("admin.dashboard.site_advice.title", {
      count: this.args.problems.length,
    });
  }

  <template>
    {{#if @problems.length}}
      <section class="db-site-advice">
        <div class="db-site-advice__header">
          <h3>{{this.title}}</h3>
          <DButton
            class="btn-transparent btn-small"
            data-test-site-advice-refresh="true"
            @action={{this.refresh}}
            @isLoading={{this.refreshing}}
            @icon="arrows-rotate"
            @label="admin.dashboard.refresh_problems"
          />
        </div>

        <ul class="db-site-advice__list">
          {{#each this.sortedProblems key="id" as |problem|}}
            <li
              class="db-site-advice__item"
              data-test-site-advice-problem={{problem.id}}
            >

              {{dIcon
                (if
                  (eq problem.priority "high")
                  "triangle-exclamation"
                  "circle-info"
                )
                class=(concat "db-site-advice__icon --" problem.priority)
              }}

              <div
                class="db-site-advice__message"
                {{linkifySettingLinks problem.message}}
              >
                {{trustHTML problem.message}}
              </div>

              {{#if this.currentUser.admin}}
                <DButton
                  class="btn-default btn-small"
                  data-test-site-advice-ignore="true"
                  @action={{fn this.ignore problem}}
                  @isLoading={{eq this.ignoringId problem.id}}
                  @label="admin.dashboard.dismiss_notice"
                />
              {{/if}}
            </li>
          {{/each}}
        </ul>
      </section>
    {{/if}}
  </template>
}
