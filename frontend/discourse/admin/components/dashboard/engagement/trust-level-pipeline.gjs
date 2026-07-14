import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";

export default class TrustLevelPipeline extends Component {
  get rows() {
    const data = this.args.data?.rows ?? [];

    const promotedIn = (row) => row.promoted_in ?? 0;
    const demotedIn = (row) => row.demoted_in ?? 0;
    const signups = (row) => row.signups ?? 0;

    // Sign-ups stay out of the scale so the entry level's sign-up volume
    // can't flatten every ladder bar.
    const barMax = data.reduce(
      (acc, row) => Math.max(acc, promotedIn(row), demotedIn(row)),
      0
    );

    return data.map((row) => {
      const promoted = promotedIn(row);
      const demoted = demotedIn(row);
      const signupCount = signups(row);
      // The bar follows whichever direction dominates: green when more members
      // were promoted into the level than demoted into it, red otherwise — so a
      // net-downward level reads as a red bar.
      const barDown = demoted > promoted;
      const barValue = barDown ? demoted : promoted;
      const hasLadderFlow = promoted > 0 || demoted > 0;
      return {
        ...row,
        label: i18n(
          `admin.dashboard.sections.engagement.trust_level_pipeline.trust_levels.${row.trust_level}`
        ),
        shareFormatted: `${I18n.toNumber(row.share, { precision: 2 })}%`,
        countFormatted: I18n.toNumber(row.count, { precision: 0 }),
        promotedInFormatted: I18n.toNumber(promoted, { precision: 0 }),
        demotedInFormatted: I18n.toNumber(demoted, { precision: 0 }),
        signups: signupCount,
        signupsFormatted: I18n.toNumber(signupCount, { precision: 0 }),
        barDown,
        hasBar: barValue > 0,
        barStyle: trustHTML(`width: ${this.#barWidth(barValue, barMax)}%`),
        hasClimbers: promoted > 0,
        hasDroppers: demoted > 0,
        hasSignups: signupCount > 0,
        hasLadderFlow,
        hasMovement: hasLadderFlow || signupCount > 0,
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
              <span
                class="db-tl-pipeline__count"
                title={{i18n
                  "admin.dashboard.sections.engagement.trust_level_pipeline.count_title"
                }}
              >
                {{row.countFormatted}}
                ({{row.shareFormatted}})
              </span>
              {{#if row.hasSignups}}
                <span
                  class="db-tl-pipeline__signups"
                  title={{i18n
                    "admin.dashboard.sections.engagement.trust_level_pipeline.signups_title"
                  }}
                >{{i18n
                    "admin.dashboard.sections.engagement.trust_level_pipeline.signups"
                    (hash count=row.signups formattedCount=row.signupsFormatted)
                  }}</span>
              {{/if}}
              {{#unless row.hasMovement}}
                <span class="db-pill">{{i18n "admin.dashboard.stable"}}</span>
              {{/unless}}
            </div>
            {{#if row.hasLadderFlow}}
              <div class="db-tl-pipeline__flow">
                <div class="db-tl-pipeline__bar-track">
                  {{#if row.hasBar}}
                    <span
                      class={{dConcatClass
                        "db-tl-pipeline__bar"
                        (if row.barDown "--demoted")
                      }}
                      style={{row.barStyle}}
                      aria-hidden="true"
                    ></span>
                  {{/if}}
                </div>
                {{#if row.hasClimbers}}
                  <span
                    class="db-delta --pos"
                    aria-label={{i18n
                      "admin.dashboard.sections.engagement.trust_level_pipeline.arrivals_aria"
                      (hash count=row.promoted_in)
                    }}
                  >{{row.promotedInFormatted}}
                    {{dIcon "arrow-up"}}</span>
                {{/if}}
                {{#if row.hasDroppers}}
                  <span
                    class="db-delta --neg"
                    aria-label={{i18n
                      "admin.dashboard.sections.engagement.trust_level_pipeline.demotions_in_aria"
                      (hash count=row.demoted_in)
                    }}
                  >{{dIcon "arrow-down"}}
                    {{row.demotedInFormatted}}</span>
                {{/if}}
              </div>
            {{/if}}
          </li>
        {{/each}}
      </ol>
    </div>
  </template>
}
