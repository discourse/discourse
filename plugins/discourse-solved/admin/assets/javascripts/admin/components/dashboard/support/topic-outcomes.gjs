import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

const ROWS = ["resolved", "in_progress", "unanswered"];

export default class SupportTopicOutcomes extends Component {
  get rows() {
    const outcomes = this.args.outcomes ?? {};
    const max = Math.max(1, ...ROWS.map((key) => outcomes[key] ?? 0));

    return ROWS.map((key) => {
      const count = outcomes[key] ?? 0;
      return {
        key,
        count,
        label: i18n(`admin.dashboard.sections.support.outcomes.${key}.label`),
        tooltip: i18n(
          `admin.dashboard.sections.support.outcomes.${key}.tooltip`
        ),
        fillStyle: trustHTML(`width: ${(count / max) * 100}%`),
        fillClass: `--${key.replace("_", "-")}`,
      };
    });
  }

  get ariaLabel() {
    return this.rows.map((row) => `${row.label} ${row.count}`).join(", ");
  }

  <template>
    <div class="db-section__row-block-header">
      <h3 class="db-section__row-block-title">
        {{i18n "admin.dashboard.sections.support.outcomes.title"}}
      </h3>
    </div>

    <div
      class="db-support-outcomes__bars"
      role="img"
      aria-label={{this.ariaLabel}}
    >
      {{#each this.rows as |row|}}
        <div class="db-support-outcomes__row">
          <span class="db-support-outcomes__label" title={{row.tooltip}}>
            {{row.label}}
          </span>
          <span class="db-support-outcomes__track">
            <span
              class={{concat "db-support-outcomes__fill " row.fillClass}}
              style={{row.fillStyle}}
            ></span>
          </span>
          <span class="db-support-outcomes__share">{{row.count}}</span>
        </div>
      {{/each}}
    </div>
  </template>
}
