import ProblemCheckItem from "discourse/admin/components/problem-check-item";
import { i18n } from "discourse-i18n";

const ProblemChecksList = <template>
  <table class="d-table admin-problem-checks__items">
    <thead class="d-table__header">
      <tr class="d-table__row">
        <th class="d-table__header-cell">{{i18n
            "admin.config.problem_checks.status"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "admin.config.problem_checks.identifier"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "admin.config.problem_checks.target"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "admin.config.problem_checks.last_run_at"
          }}</th>
        <th class="d-table__header-cell"></th>
      </tr>
    </thead>
    <tbody class="d-table__body">
      {{#each @problemChecks as |tracker|}}
        <ProblemCheckItem @tracker={{tracker}} />
      {{/each}}
    </tbody>
  </table>
</template>;

export default ProblemChecksList;
