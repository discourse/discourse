import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminNotice from "admin/components/admin-notice";

export default class DashboardProblems extends Component {
  @action
  async dismissProblem(problem) {
    try {
      await ajax(`/admin/admin_notices/${problem.id}`, { type: "DELETE" });
      this.args.problems.removeObject(problem);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get problems() {
    return this.args.problems.sortBy("priority");
  }

  <template>
    {{#if @problems.length}}
      <div class="section dashboard-problems">
        <div class="section-title">
          <h2>
            {{icon "heart"}}
            {{i18n "admin.dashboard.problems_found"}}
          </h2>
        </div>

        <div class="section-body">
          <ConditionalLoadingSection @isLoading={{@loadingProblems}}>
            <div class="problem-messages">
              <ul>
                {{#each this.problems as |problem|}}
                  <li
                    class={{concatClass
                      "dashboard-problem"
                      (concat "priority-" problem.priority)
                    }}
                  >
                    <AdminNotice
                      @icon={{if
                        (eq problem.priority "high")
                        "triangle-exclamation"
                      }}
                      @problem={{problem}}
                      @dismissCallback={{this.dismissProblem}}
                    />
                  </li>
                {{/each}}
              </ul>
            </div>

            <p class="actions">
              <DButton
                @action={{@refreshProblems}}
                @icon="arrows-rotate"
                @label="admin.dashboard.refresh_problems"
                class="btn-default"
              />
              {{i18n "admin.dashboard.last_checked"}}:
              {{@problemsTimestamp}}
            </p>
          </ConditionalLoadingSection>
        </div>
      </div>
    {{/if}}
  </template>
}
