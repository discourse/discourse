import number from "discourse/helpers/number";
import { i18n } from "discourse-i18n";

const Assignments = <template>
  <div class="rewind-report-page --assignments">
    <div class="sticky-board">
      <div class="sticky-note --yellow --rotate-left">
        <div class="sticky-note__content">
          <div class="sticky-note__title">
            {{i18n "discourse_rewind.reports.assignments.completed"}}
          </div>
          <div class="sticky-note__value">
            {{number @report.data.completed}}
          </div>
        </div>
      </div>

      <div class="sticky-note --pink --rotate-right">
        <div class="sticky-note__content">
          <div class="sticky-note__title">
            {{i18n "discourse_rewind.reports.assignments.pending"}}
          </div>
          <div class="sticky-note__value">{{number @report.data.pending}}</div>
        </div>
      </div>

      <div class="sticky-note --blue --rotate-left-small">
        <div class="sticky-note__content">
          <div class="sticky-note__title">
            {{i18n "discourse_rewind.reports.assignments.total_assigned"}}
          </div>
          <div class="sticky-note__value">
            {{number @report.data.total_assigned}}
          </div>
        </div>
      </div>

      <div class="sticky-note --green --rotate-right-small">
        <div class="sticky-note__content">
          <div class="sticky-note__title">
            {{i18n "discourse_rewind.reports.assignments.assigned_by_user"}}
          </div>
          <div class="sticky-note__value">
            {{number @report.data.assigned_by_user}}
          </div>
        </div>
      </div>

      <div class="sticky-note --orange">
        <div class="sticky-note__content">
          <div class="sticky-note__title">
            {{i18n "discourse_rewind.reports.assignments.completion_rate"}}
          </div>
          <div
            class="sticky-note__value"
          >{{@report.data.completion_rate}}%</div>
        </div>
      </div>
    </div>
  </div>
</template>;

export default Assignments;
