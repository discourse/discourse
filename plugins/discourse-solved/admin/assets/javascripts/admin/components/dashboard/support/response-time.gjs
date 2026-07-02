import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { durationTiny } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";

const BUCKETS = ["lt_1h", "1_4h", "4_24h", "gt_24h"];

export default class SupportResponseTime extends Component {
  get rows() {
    const byKey = Object.fromEntries(
      (this.args.data?.buckets ?? []).map((bucket) => [bucket.key, bucket])
    );

    return BUCKETS.map((key) => {
      const share = byKey[key]?.share ?? 0;
      return {
        key,
        share,
        shareFormatted: `${Math.round(share)}%`,
        label: i18n(
          `admin.dashboard.sections.support.response_time.buckets.${key}`
        ),
        fillStyle: trustHTML(`width: ${share}%`),
        fillClass: `--bucket-${key}`,
      };
    });
  }

  get ariaLabel() {
    return this.rows
      .map((row) => `${row.label} ${row.shareFormatted}`)
      .join(", ");
  }

  get trend() {
    const trend = this.args.data?.trend;
    if (!trend || trend.direction === "flat" || !trend.seconds) {
      return null;
    }
    return {
      direction: trend.direction,
      modifier: `--${trend.direction}`,
      label: i18n(
        `admin.dashboard.sections.support.response_time.trend.${trend.direction}`,
        { duration: durationTiny(trend.seconds) }
      ),
    };
  }

  <template>
    <div class="db-support-response">
      <div class="db-support-response__header">
        <h3 class="db-support-response__title">
          {{i18n "admin.dashboard.sections.support.response_time.title"}}
        </h3>
        {{#if this.trend}}
          <span
            class={{concat
              "db-pill db-support-response__trend "
              this.trend.modifier
            }}
          >
            {{this.trend.label}}
            <DTooltip
              class="db-support-response__info"
              @icon="far-circle-question"
              @content={{i18n
                "admin.dashboard.sections.support.response_time.trend.tooltip"
              }}
            />
          </span>
        {{/if}}
      </div>

      <div
        class="db-support-response__bars"
        role="img"
        aria-label={{this.ariaLabel}}
      >
        {{#each this.rows as |row|}}
          <div class="db-support-response__row">
            <span class="db-support-response__label">{{row.label}}</span>
            <span class="db-support-response__track">
              <span
                class={{concat "db-support-response__fill " row.fillClass}}
                style={{row.fillStyle}}
              ></span>
            </span>
            <span
              class="db-support-response__share"
            >{{row.shareFormatted}}</span>
          </div>
        {{/each}}
      </div>
    </div>
  </template>
}
