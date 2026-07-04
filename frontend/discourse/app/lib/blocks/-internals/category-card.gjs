// @ts-check
import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

/**
 * Reusable category card UI shared by the `featured-categories` block (a
 * grid of categories) and the `category-banner` block (its subcategory
 * list). Renders a coloured square / icon / emoji badge, the category
 * name, and an optional description.
 */
export default class CategoryCard extends Component {
  /**
   * Inline style for the badge container — full-colour foreground with a
   * tinted lower-alpha background so the icon stands out against the
   * category's brand colour.
   *
   * @returns {ReturnType<typeof trustHTML>}
   */
  get logoStyle() {
    const color = this.args.category?.color;
    return trustHTML(
      `color: #${color}; background-color: ${this.#lighterColor(color)};`
    );
  }

  /**
   * Inline style for the solid-colour fallback square that renders when
   * the category has no icon or emoji to display.
   *
   * @returns {ReturnType<typeof trustHTML>}
   */
  get logoSquareStyle() {
    const color = this.args.category?.color;
    if (!color) {
      return trustHTML("background-color: var(--primary);");
    }
    return trustHTML(`background-color: #${color};`);
  }

  /**
   * Normalises a Discourse emoji string into the `:name:` shortcode form
   * that `replaceEmoji` expects.
   *
   * @param {string} [emoji]
   * @returns {string|undefined}
   */
  formatEmoji(emoji) {
    if (!emoji) {
      return emoji;
    }
    return emoji.startsWith(":") ? emoji : `:${emoji}:`;
  }

  /**
   * Builds a low-alpha variant of the category colour for the logo
   * background. Returns a safe fallback when no colour is set.
   *
   * @param {string} [hex]
   * @returns {string}
   */
  #lighterColor(hex) {
    if (!hex) {
      return "rgba(245, 245, 245, 0.15)";
    }
    let c = hex.replace("#", "");
    if (c.length === 3) {
      c = c
        .split("")
        .map((x) => x + x)
        .join("");
    }
    const r = parseInt(c.substring(0, 2), 16);
    const g = parseInt(c.substring(2, 4), 16);
    const b = parseInt(c.substring(4, 6), 16);
    return `rgba(${r}, ${g}, ${b}, 0.15)`;
  }

  <template>
    {{#if @href}}
      <a class={{concat "d-block-category-card " @class}} href={{@href}}>
        <div class="d-block-category-card__logo" style={{this.logoStyle}}>
          {{#if @category.icon}}
            {{dIcon @category.icon}}
          {{else if @category.emoji}}
            {{dReplaceEmoji (this.formatEmoji @category.emoji)}}
          {{else}}
            <span
              class="d-block-category-card__logo-square"
              style={{this.logoSquareStyle}}
            ></span>
          {{/if}}
        </div>

        <div class="d-block-category-card__details">
          <h3 class="d-block-category-card__name">{{@category.name}}</h3>

          {{#if @showDescription}}
            <span class="d-block-category-card__description">
              {{trustHTML @description}}
            </span>
          {{/if}}
        </div>
      </a>
    {{else}}
      <div class={{concat "d-block-category-card " @class}}>
        <div class="d-block-category-card__logo" style={{this.logoStyle}}>
          {{#if @category.icon}}
            {{dIcon @category.icon}}
          {{else if @category.emoji}}
            {{dReplaceEmoji (this.formatEmoji @category.emoji)}}
          {{else}}
            <span
              class="d-block-category-card__logo-square"
              style={{this.logoSquareStyle}}
            ></span>
          {{/if}}
        </div>

        <div class="d-block-category-card__details">
          <h3 class="d-block-category-card__name">{{@category.name}}</h3>

          {{#if @showDescription}}
            <span class="d-block-category-card__description">
              {{trustHTML @description}}
            </span>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
