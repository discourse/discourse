import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class BlogThemeThumbnail extends Component {
  get style() {
    const theme = this.args.theme;
    return trustHTML(
      `--blog-theme-paper: ${this.#paint(theme.paper_color, "var(--secondary)")};` +
        `--blog-theme-ink: ${this.#paint(theme.ink_color, "var(--primary)")};` +
        `--blog-theme-accent: ${this.#paint(theme.accent_color, "var(--tertiary)")};`
    );
  }

  #paint(value, fallback) {
    return /^[0-9a-f]{6}$/i.test(value) ? `#${value}` : fallback;
  }

  <template>
    <div class="blog-theme-thumbnail" style={{this.style}} ...attributes>
      <div class="blog-theme-thumbnail__eyebrow">{{i18n
          "blog.admin.thumbnail.journal"
        }}</div>
      <div class="blog-theme-thumbnail__headline">{{i18n
          "blog.admin.thumbnail.headline"
        }}</div>
      <p class="blog-theme-thumbnail__excerpt">{{i18n
          "blog.admin.thumbnail.excerpt"
        }}</p>
      <div class="blog-theme-thumbnail__palette">
        <span
          aria-hidden="true"
          class="blog-theme-thumbnail__swatch --ink"
        ></span>
        <span
          aria-hidden="true"
          class="blog-theme-thumbnail__swatch --accent"
        ></span>
        <span
          aria-hidden="true"
          class="blog-theme-thumbnail__swatch --paper"
        ></span>
        <span class="blog-theme-thumbnail__caption">{{i18n
            "blog.admin.thumbnail.palette"
          }}</span>
      </div>
    </div>
  </template>
}
