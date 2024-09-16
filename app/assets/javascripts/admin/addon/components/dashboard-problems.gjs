import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
export default class DashboardProblems extends Component {
  <template>
    {{#if @foundProblems}}
      <div class="section dashboard-problems">
        <div class="section-title">
          <h2>
            {{icon "heart"}}
            {{i18n "admin.dashboard.problems_found"}}
          </h2>
        </div>

        <div class="section-body">
          <ConditionalLoadingSection @isLoading={{@loadingProblems}}>
            {{#if @highPriorityProblems.length}}
              <div class="problem-messages priority-high">
                <ul>
                  {{#each @highPriorityProblems as |problem|}}
                    <li
                      class={{concatClass
                        "dashboard-problem "
                        "priority-"
                        problem.priority
                      }}
                    >
                      {{icon "triangle-exclamation"}}
                      {{htmlSafe problem.message}}
                    </li>
                  {{/each}}
                </ul>
              </div>
            {{/if}}

            <div class="problem-messages priority-low">
              <ul>
                {{#each @lowPriorityProblems as |problem|}}
                  <li
                    class={{concatClass
                      "dashboard-problem "
                      "priority-"
                      problem.priority
                    }}
                  >{{htmlSafe problem.message}}</li>
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
