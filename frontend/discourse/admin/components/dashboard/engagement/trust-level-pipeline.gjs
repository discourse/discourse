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
    // Each rung reports who arrived this period, split by direction. Members
    // rise into a level (promoted_in) or, at the entry level, join (signups) —
    // both are upward arrivals. Members can also fall into a level from above
    // (demoted_in), a downward arrival.
    const promotedIn = (row) => row.promoted_in ?? 0;
    const demotedIn = (row) => row.demoted_in ?? 0;
    const signups = (row) => row.signups ?? 0;

    // The lowest trust level is the entry point: members reach it by signing
    // up, not by climbing the ladder. It never draws a bar — its numbers sit
    // inline on the title row instead — and it's excluded from the bar scale so
    // its sign-up firehose doesn't dwarf every other level.
    const entryLevel = data.reduce(
      (min, row) => Math.min(min, row.trust_level),
      Infinity
    );
    const barMax = data.reduce(
      (acc, row) =>
        row.trust_level === entryLevel
          ? acc
          : Math.max(acc, promotedIn(row), demotedIn(row)),
      0
    );

    return data.map((row) => {
      const isEntry = row.trust_level === entryLevel;
      const climbedIn = promotedIn(row) + signups(row);
      const droppedIn = demotedIn(row);
      // Within the ladder flow, the bar follows whichever direction dominates:
      // green when more members were promoted into the level than demoted into
      // it, red otherwise — so a net-downward level reads as a red bar.
      const barDown = droppedIn > promotedIn(row);
      const barValue = barDown ? droppedIn : promotedIn(row);
      const hasMovement = climbedIn > 0 || droppedIn > 0;
      return {
        ...row,
        label: i18n(
          `admin.dashboard.sections.engagement.trust_level_pipeline.trust_levels.${row.trust_level}`
        ),
        shareFormatted: `${I18n.toNumber(row.share, { precision: 2 })}%`,
        countFormatted: I18n.toNumber(row.count, { precision: 0 }),
        climbedInFormatted: I18n.toNumber(climbedIn, { precision: 0 }),
        droppedInFormatted: I18n.toNumber(droppedIn, { precision: 0 }),
        climbedIn,
        droppedIn,
        barDown,
        hasBar: !isEntry && barValue > 0,
        barStyle: trustHTML(`width: ${this.#barWidth(barValue, barMax)}%`),
        hasClimbers: climbedIn > 0,
        hasDroppers: droppedIn > 0,
        hasMovement,
        // The entry level has no bar, so its deltas sit inline on the title
        // row; every other level shows them beside its bar on the row below.
        showInlineDeltas: isEntry && hasMovement,
        showFlow: !isEntry && hasMovement,
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
              {{#if row.showInlineDeltas}}
                <span class="db-tl-pipeline__deltas">
                  {{#if row.hasClimbers}}
                    <span
                      class="db-delta --pos"
                      aria-label={{i18n
                        "admin.dashboard.sections.engagement.trust_level_pipeline.arrivals_aria"
                        (hash count=row.climbedIn)
                      }}
                    >{{row.climbedInFormatted}}
                      {{dIcon "arrow-up"}}</span>
                  {{/if}}
                  {{#if row.hasDroppers}}
                    <span
                      class="db-delta --neg"
                      aria-label={{i18n
                        "admin.dashboard.sections.engagement.trust_level_pipeline.demotions_in_aria"
                        (hash count=row.droppedIn)
                      }}
                    >{{dIcon "arrow-down"}}
                      {{row.droppedInFormatted}}</span>
                  {{/if}}
                </span>
              {{/if}}
              {{#unless row.hasMovement}}
                <span class="db-pill">{{i18n "admin.dashboard.stable"}}</span>
              {{/unless}}
            </div>
            {{#if row.showFlow}}
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
                      (hash count=row.climbedIn)
                    }}
                  >{{row.climbedInFormatted}}
                    {{dIcon "arrow-up"}}</span>
                {{/if}}
                {{#if row.hasDroppers}}
                  <span
                    class="db-delta --neg"
                    aria-label={{i18n
                      "admin.dashboard.sections.engagement.trust_level_pipeline.demotions_in_aria"
                      (hash count=row.droppedIn)
                    }}
                  >{{dIcon "arrow-down"}}
                    {{row.droppedInFormatted}}</span>
                {{/if}}
              </div>
            {{/if}}
          </li>
        {{/each}}
      </ol>
    </div>
  </template>
}
