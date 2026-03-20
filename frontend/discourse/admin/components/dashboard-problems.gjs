import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { compare } from "@ember/utils";
import AdminNotice from "discourse/admin/components/admin-notice";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSection from "discourse/ui-kit/d-conditional-loading-section";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DashboardProblems extends Component {
  @action
  async dismissProblem(problem) {
    try {
      await ajax(`/admin/admin_notices/${problem.id}`, { type: "DELETE" });
      removeValueFromArray(this.args.problems, problem);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get problems() {
    return this.args.problems.toSorted((a, b) =>
      compare(a?.priority, b?.priority)
    );
  }

  <template>
    {{#if @problems.length}}
      <div class="section dashboard-problems">
        <div class="section-title">
          <h2>
            {{dIcon "heart"}}
            {{i18n "admin.dashboard.problems_found"}}
          </h2>
        </div>

        <div class="section-body">
          <DConditionalLoadingSection @isLoading={{@loadingProblems}}>
            <div class="problem-messages">
              <ul>
                {{#each this.problems as |problem|}}
                  <li
                    class={{dConcatClass
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
          </DConditionalLoadingSection>
        </div>
      </div>
    {{/if}}
  </template>
}
