import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import I18n, { i18n } from "discourse-i18n";

export default class TrustLevelPipeline extends Component {
  get rows() {
    const data = this.args.data?.rows ?? [];
    const max = data.reduce(
      (acc, row) => Math.max(acc, row.moves_in, row.moves_out),
      0
    );

    return data.map((row) => {
      const widthIn = this.#barWidth(row.moves_in, max);
      const widthOut = this.#barWidth(row.moves_out, max);
      return {
        ...row,
        label: i18n(
          `admin.dashboard.sections.engagement.trust_level_pipeline.trust_levels.${row.trust_level}`
        ),
        shareFormatted: `${I18n.toNumber(row.share, { precision: 2 })}%`,
        countFormatted: I18n.toNumber(row.count, { precision: 0 }),
        barInStyle: trustHTML(`width: ${widthIn}%`),
        barOutStyle: trustHTML(`width: ${widthOut}%`),
        hasMovement: row.moves_in > 0 || row.moves_out > 0,
      };
    });
  }

  #barWidth(value, max) {
    if (max === 0 || value === 0) {
      return 0;
    }
    return Math.round((value / max) * 100);
  }

  get trendClass() {
    const direction = this.args.data?.trend?.direction;
    if (direction === "climbing") {
      return "--pos";
    }
    if (direction === "dropping") {
      return "--neg";
    }
    return "";
  }

  get trendText() {
    const trend = this.args.data?.trend;
    if (!trend) {
      return null;
    }
    if (trend.direction === "stable") {
      return i18n("admin.dashboard.stable");
    }
    return i18n(
      `admin.dashboard.sections.engagement.trust_level_pipeline.trend.${trend.direction}`,
      { count: trend.net }
    );
  }

  <template>
    <div class="db-tl-pipeline">
      <div class="db-section__row-block-header">
        <LinkTo
          @route="adminReports.show"
          @model="trust_level_pipeline"
          class="db-section__row-block-title --label"
        >
          {{i18n
            "admin.dashboard.sections.engagement.trust_level_pipeline.title"
          }}
        </LinkTo>
        {{#if this.trendText}}
          <span
            class={{concat "db-pill " this.trendClass}}
          >{{this.trendText}}</span>
        {{/if}}
      </div>

      <ol class="db-tl-pipeline__rows">
        {{#each this.rows as |row|}}
          <li class="db-tl-pipeline__row">
            <div class="db-tl-pipeline__label">
              <span class="db-tl-pipeline__name">{{row.label}}</span>
              <span class="db-tl-pipeline__count">
                {{row.countFormatted}}
                ({{row.shareFormatted}})
              </span>
            </div>
            {{#if row.hasMovement}}
              <div class="db-tl-pipeline__bars">
                <div class="db-tl-pipeline__bar-out">
                  {{#if row.moves_out}}
                    <span
                      class="db-tl-pipeline__delta db-tl-pipeline__delta--out"
                    >↓
                      {{row.moves_out}}</span>
                    <div class="db-tl-pipeline__bar-track">
                      <span
                        class="db-tl-pipeline__bar db-tl-pipeline__bar--out"
                        style={{row.barOutStyle}}
                        aria-label={{i18n
                          "admin.dashboard.sections.engagement.trust_level_pipeline.moves_out_aria"
                          (hash count=row.moves_out)
                        }}
                      ></span>
                    </div>
                  {{else}}
                    <span class="db-pill">{{i18n
                        "admin.dashboard.stable"
                      }}</span>
                  {{/if}}
                </div>
                <div class="db-tl-pipeline__divider"></div>
                <div class="db-tl-pipeline__bar-in">
                  {{#if row.moves_in}}
                    <div class="db-tl-pipeline__bar-track">
                      <span
                        class="db-tl-pipeline__bar db-tl-pipeline__bar--in"
                        style={{row.barInStyle}}
                        aria-label={{i18n
                          "admin.dashboard.sections.engagement.trust_level_pipeline.moves_in_aria"
                          (hash count=row.moves_in)
                        }}
                      ></span>
                    </div>
                    <span
                      class="db-tl-pipeline__delta db-tl-pipeline__delta--in"
                    >{{row.moves_in}}
                      ↑</span>
                  {{else}}
                    <span class="db-pill">{{i18n
                        "admin.dashboard.stable"
                      }}</span>
                  {{/if}}
                </div>
              </div>
            {{/if}}
          </li>
        {{/each}}
      </ol>
    </div>
  </template>
}
