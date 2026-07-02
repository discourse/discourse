import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import DTooltip from "discourse/float-kit/components/d-tooltip";
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

  <template>
    <div class="db-support-outcomes">
      <h3 class="db-support-outcomes__title">
        {{i18n "admin.dashboard.sections.support.outcomes.title"}}
      </h3>
      {{#each this.rows as |row|}}
        <div class="db-support-outcomes__row">
          <div class="db-support-outcomes__head">
            <span class="db-support-outcomes__label">
              {{row.label}}
              <DTooltip
                class="db-support-outcomes__info"
                @identifier={{concat "support-outcome-" row.key "-tooltip"}}
                @icon="far-circle-question"
                @content={{row.tooltip}}
              />
            </span>
            <span class="db-support-outcomes__count">{{row.count}}</span>
          </div>
          <span class="db-support-outcomes__track">
            <span
              class={{concat "db-support-outcomes__fill " row.fillClass}}
              style={{row.fillStyle}}
            ></span>
          </span>
        </div>
      {{/each}}
    </div>
  </template>
}
