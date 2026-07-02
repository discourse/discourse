import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

// Rendered in descending share order, matching the design; buckets with no
// activity are omitted.
export default class SupportWhosAnswering extends Component {
  get rows() {
    const data = this.args.data ?? {};
    return (data.rows ?? [])
      .filter((row) => row.count > 0)
      .sort((a, b) => b.share - a.share)
      .map((row) => ({
        type: row.type,
        share: row.share,
        shareFormatted: `${Math.round(row.share)}%`,
        label: i18n(`admin.dashboard.sections.support.answerers.${row.type}`),
        fillStyle: trustHTML(`width: ${row.share}%`),
        fillClass: `--${row.type}`,
      }));
  }

  get hasData() {
    return (this.args.data?.total ?? 0) > 0;
  }

  get ariaLabel() {
    return this.rows.map((r) => `${r.label} ${r.shareFormatted}`).join(", ");
  }

  <template>
    <div class="db-section__row-block-header">
      <h3 class="db-section__row-block-title">
        {{i18n "admin.dashboard.sections.support.answerers.title"}}
      </h3>
    </div>

    {{#if this.hasData}}
      <div
        class="db-whos-posting__bars"
        role="img"
        aria-label={{this.ariaLabel}}
      >
        {{#each this.rows as |row|}}
          <div class="db-whos-posting__bar-row">
            <span class="db-whos-posting__bar-label">{{row.label}}</span>
            <span class="db-whos-posting__bar-track">
              <span
                class={{concat "db-whos-posting__bar-fill " row.fillClass}}
                style={{row.fillStyle}}
              ></span>
            </span>
            <span
              class="db-whos-posting__bar-share"
            >{{row.shareFormatted}}</span>
          </div>
        {{/each}}
      </div>
    {{else}}
      <p class="db-whos-posting__empty">
        {{i18n "admin.dashboard.sections.support.answerers.empty"}}
      </p>
    {{/if}}
  </template>
}
