import { get } from "@ember/helper";
import formatDate from "discourse/helpers/format-date";
import { notEq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const STATUS_CLASSES = {
  passing: "--success",
  failing: "--critical",
};

const STATUS_LABELS = {
  passing: i18n("admin.config.problem_checks.passing"),
  failing: i18n("admin.config.problem_checks.failing"),
};

const ProblemCheckItem = <template>
  <tr class="d-table__row --{{@tracker.status}}">
    <td class="d-table__cell --overview">
      <div class="status-label {{get STATUS_CLASSES @tracker.status}}">
        <div class="status-label-indicator"></div>
        <div class="status-label-text">
          {{get STATUS_LABELS @tracker.status}}
        </div>
      </div>
    </td>
    <td class="d-table__cell --detail">
      <div class="d-table__mobile-label">{{i18n
          "admin.config.problem_checks.identifier"
        }}</div>
      {{@tracker.identifier}}
    </td>
    <td class="d-table__cell --detail">
      <div class="d-table__mobile-label">{{i18n
          "admin.config.problem_checks.target"
        }}</div>
      {{#if (notEq @tracker.target "__NULL__")}}
        {{@tracker.target}}
      {{/if}}
    </td>
    <td class="d-table__cell --detail">
      <div class="d-table__mobile-label">{{i18n
          "admin.config.problem_checks.last_run_at"
        }}</div>
      {{#if @tracker.last_run_at}}
        {{formatDate @tracker.last_run_at leaveAgo="true"}}
      {{/if}}
    </td>
    <td class="d-table__cell --controls"></td>
  </tr>
</template>;

export default ProblemCheckItem;
