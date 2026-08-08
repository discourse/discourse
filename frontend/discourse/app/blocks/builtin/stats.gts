import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { ICON_NAME_PATTERN, URL_PATTERN } from "discourse/lib/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/** A single statistic, edited through the repeatable `items` arg. */
interface StatItem {
  value?: string;
  label?: string;
  icon?: string;
  href?: string;
}

interface StatsSignature {
  Args: {
    columns?: number;
    gap?: number;
    items?: StatItem[];
  };
}

/**
 * A row of statistics — each a large value with a label and an optional icon,
 * optionally linked. The stats are a single `items` arg (an array of
 * `{ value, label, icon, href }` objects) reflowed into equal columns.
 */
@block("stats", {
  thumbnail: () => import("discourse/blocks/thumbnails/stats"),
  displayName: "Stats",
  icon: "chart-column",
  category: "Content",
  description: "A row of statistics, each a value with a label.",
  args: {
    columns: {
      type: "number",
      default: 4,
      integer: true,
      min: 1,
      max: 8,
      ui: { label: i18n("blocks.builtin.stats.columns") },
    },
    gap: {
      type: "number",
      default: 1,
      min: 0,
      max: 4,
      ui: { label: i18n("blocks.builtin.stats.gap") },
    },
    items: {
      type: "array",
      itemType: "object",
      default: [],
      itemSchema: {
        value: {
          type: "string",
          required: true,
          ui: { label: i18n("blocks.builtin.stats.item_value") },
        },
        label: {
          type: "string",
          required: true,
          ui: { label: i18n("blocks.builtin.stats.item_label") },
        },
        icon: {
          type: "string",
          pattern: ICON_NAME_PATTERN,
          ui: {
            control: "icon",
            label: i18n("blocks.builtin.stats.item_icon"),
          },
        },
        href: {
          type: "string",
          pattern: URL_PATTERN,
          ui: {
            control: "url",
            label: i18n("blocks.builtin.stats.item_href"),
          },
        },
      },
      ui: {
        control: "repeatable",
        label: i18n("blocks.builtin.stats.items"),
      },
    },
  },
})
export default class Stats extends Component<StatsSignature> {
  get items(): StatItem[] {
    return this.args.items ?? [];
  }

  /**
   * Grid sizing (column count + gap) emitted as CSS custom properties.
   *
   * @returns The inline custom-property declarations.
   */
  get gridStyle() {
    const columns = this.args.columns ?? 4;
    const gap = this.args.gap ?? 1;
    return trustHTML(
      `--d-block-stats-columns: ${columns}; --d-block-stats-gap: ${gap}rem`
    );
  }

  <template>
    <div class="d-block-stats" style={{this.gridStyle}}>
      {{#each this.items key="@index" as |item|}}
        {{#if item.href}}
          <a class="d-block-stats__item" href={{item.href}}>
            {{#if item.icon}}
              <span class="d-block-stats__icon">{{dIcon item.icon}}</span>
            {{/if}}
            <span class="d-block-stats__value">{{item.value}}</span>
            <span class="d-block-stats__label">{{item.label}}</span>
          </a>
        {{else}}
          <div class="d-block-stats__item">
            {{#if item.icon}}
              <span class="d-block-stats__icon">{{dIcon item.icon}}</span>
            {{/if}}
            <span class="d-block-stats__value">{{item.value}}</span>
            <span class="d-block-stats__label">{{item.label}}</span>
          </div>
        {{/if}}
      {{/each}}
    </div>
  </template>
}
