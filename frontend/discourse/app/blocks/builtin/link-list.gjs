// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { ICON_NAME_PATTERN, URL_PATTERN } from "discourse/lib/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VALID_LAYOUTS = ["vertical", "horizontal"];

/**
 * A list of links, each an optional icon plus a label, laid out vertically
 * (a stacked menu) or horizontally (a nav / button bar). The links are a
 * single `items` arg — an array of `{ label, url, icon }` objects — so the
 * whole list is edited as one repeatable field rather than as separate child
 * blocks.
 */
@block("link-list", {
  displayName: "Link list",
  icon: "link",
  category: "Content",
  description: "A list of links, laid out vertically or horizontally.",
  args: {
    layout: {
      type: "string",
      default: "vertical",
      enum: VALID_LAYOUTS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.link_list.layout"),
      },
    },
    gap: {
      type: "number",
      default: 0.5,
      min: 0,
      max: 4,
      ui: { label: i18n("blocks.builtin.link_list.gap") },
    },
    items: {
      type: "array",
      itemType: "object",
      default: [],
      itemSchema: {
        label: {
          type: "string",
          required: true,
          ui: { label: i18n("blocks.builtin.link_list.item_label") },
        },
        url: {
          type: "string",
          required: true,
          pattern: URL_PATTERN,
          ui: {
            control: "url",
            label: i18n("blocks.builtin.link_list.item_url"),
          },
        },
        icon: {
          type: "string",
          pattern: ICON_NAME_PATTERN,
          ui: {
            control: "icon",
            label: i18n("blocks.builtin.link_list.item_icon"),
          },
        },
        description: {
          type: "string",
          ui: {
            label: i18n("blocks.builtin.link_list.item_description"),
          },
        },
      },
      ui: {
        control: "repeatable",
        label: i18n("blocks.builtin.link_list.items"),
      },
    },
  },
})
export default class LinkList extends Component {
  get items() {
    return this.args.items ?? [];
  }

  /**
   * Class list with the orientation modifier.
   *
   * @returns {string}
   */
  get className() {
    const layout = VALID_LAYOUTS.includes(this.args.layout)
      ? this.args.layout
      : "vertical";
    return `d-block-link-list d-block-link-list--${layout}`;
  }

  /**
   * Gap between items, emitted as a CSS custom property.
   *
   * @returns {ReturnType<typeof trustHTML>}
   */
  get gapStyle() {
    const gap = this.args.gap ?? 0.5;
    return trustHTML(`--d-block-link-list-gap: ${gap}rem`);
  }

  <template>
    <nav class={{this.className}} style={{this.gapStyle}}>
      <ul class="d-block-link-list__items">
        {{#each this.items key="@index" as |item|}}
          <li class="d-block-link-list__item">
            <a class="d-block-link-list__link" href={{item.url}}>
              {{#if item.icon}}
                <span class="d-block-inline-icon">{{dIcon item.icon}}</span>
              {{/if}}
              <span class="d-block-link-list__text">
                <span class="d-block-link-list__label">{{item.label}}</span>
                {{#if item.description}}
                  <span
                    class="d-block-link-list__description"
                  >{{item.description}}</span>
                {{/if}}
              </span>
            </a>
          </li>
        {{/each}}
      </ul>
    </nav>
  </template>
}
