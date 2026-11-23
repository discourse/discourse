import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
import RewindWindow from "discourse/plugins/discourse-rewind/discourse/components/rewind-window";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

const BOX_LIMIT = 100;

export default class Assignments extends Component {
  get totalAssignedText() {
    return i18nForOwner(
      "discourse_rewind.reports.assignments.total_assigned",
      this.args.isOwnRewind,
      { username: this.args.user?.username }
    );
  }

  /**
   * One checkbox per assignment, ticked when done, capped so a busy year stays readable.
   */
  get boxes() {
    const { completed, total_assigned: total } = this.args.report.data;
    const shown = Math.min(total, BOX_LIMIT);
    const ticked = Math.round((completed / Math.max(total, 1)) * shown);
    return Array.from({ length: shown }, (_, index) => index < ticked);
  }

  get completionStyle() {
    return trustHTML(`width: ${this.args.report.data.completion_rate}%`);
  }

  <template>
    <div class="rewind-report-page --assignments">
      <h2 class="rewind-report-title">{{this.totalAssignedText}}</h2>
      <div class="rewind-todo">
        <RewindWindow>
          <p class="rewind-stat__value">{{dNumber
              @report.data.total_assigned
            }}</p>
          <ul aria-hidden="true" class="rewind-todo__boxes">
            {{#each this.boxes as |done|}}
              <li class="rewind-todo__box {{if done '--done'}}"></li>
            {{/each}}
          </ul>
        </RewindWindow>

        <div class="rewind-todo__stats">
          <div class="rewind-stat">
            <span class="rewind-stat__label">{{i18n
                "discourse_rewind.reports.assignments.completion_rate"
              }}</span>
            <span
              class="rewind-stat__value"
            >{{@report.data.completion_rate}}%</span>
            <span class="rewind-todo__meter">
              <span
                class="rewind-todo__meter-fill"
                style={{this.completionStyle}}
              ></span>
            </span>
          </div>
          <dl class="rewind-stats">
            <div class="rewind-stat">
              <dt class="rewind-stat__label">{{i18n
                  "discourse_rewind.reports.assignments.completed"
                }}</dt>
              <dd class="rewind-stat__value">{{dNumber
                  @report.data.completed
                }}</dd>
            </div>
            <div class="rewind-stat">
              <dt class="rewind-stat__label">{{i18n
                  "discourse_rewind.reports.assignments.pending"
                }}</dt>
              <dd class="rewind-stat__value">{{dNumber
                  @report.data.pending
                }}</dd>
            </div>
            <div class="rewind-stat">
              <dt class="rewind-stat__label">{{i18n
                  "discourse_rewind.reports.assignments.assigned_by_user"
                }}</dt>
              <dd class="rewind-stat__value">{{dNumber
                  @report.data.assigned_by_user
                }}</dd>
            </div>
          </dl>
        </div>
      </div>
    </div>
  </template>
}
