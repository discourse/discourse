// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { HEX_COLOR_PATTERN, URL_PATTERN } from "discourse/lib/blocks";
import { i18n } from "discourse-i18n";

const VALID_CONTENT_ALIGNS = ["start", "center", "end"];
const VALID_CONTENT_WIDTHS = ["contained", "wide", "full"];

/**
 * Full-bleed section / hero. A container whose own content (a heading, some
 * text, a button) is composed from ordinary child blocks, rendered over an
 * optional background (image, solid colour, or gradient) and an optional
 * colour overlay.
 *
 * When an `href` is set the whole section becomes a single link via the
 * stretched-link affordance (a positioned anchor covering the section) rather
 * than wrapping the children in an `<a>` — that keeps any inner links or
 * buttons clickable and the markup valid. The `linkLabel` supplies the link's
 * accessible name.
 */
@block("section", {
  thumbnail: () => import("discourse/blocks/thumbnails/section"),
  container: true,
  displayName: "Section",
  icon: "image",
  category: "Layout",
  description:
    "A full-bleed section with an optional background and overlaid content.",
  args: {
    background: {
      type: "image",
      allowDark: true,
      allowResize: false,
      aspectRatio: "auto",
      defaultFit: "cover",
      ui: {
        label: i18n("blocks.builtin.section.background"),
        group: "Background",
      },
    },
    backgroundColor: {
      type: "string",
      pattern: HEX_COLOR_PATTERN,
      ui: {
        control: "color",
        group: "Background",
        label: i18n("blocks.builtin.section.background_color"),
      },
    },
    gradient: {
      type: "string",
      default: "",
      ui: {
        group: "Background",
        label: i18n("blocks.builtin.section.gradient"),
        placeholder: i18n("blocks.builtin.section.gradient_placeholder"),
      },
    },
    overlayColor: {
      type: "string",
      pattern: HEX_COLOR_PATTERN,
      ui: {
        control: "color",
        group: "Overlay",
        label: i18n("blocks.builtin.section.overlay_color"),
      },
    },
    overlayOpacity: {
      type: "number",
      default: 0,
      min: 0,
      max: 1,
      ui: {
        group: "Overlay",
        label: i18n("blocks.builtin.section.overlay_opacity"),
      },
    },
    minHeight: {
      type: "string",
      default: "",
      ui: {
        label: i18n("blocks.builtin.section.min_height"),
        placeholder: i18n("blocks.builtin.section.min_height_placeholder"),
      },
    },
    contentAlign: {
      type: "string",
      default: "center",
      enum: VALID_CONTENT_ALIGNS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.section.content_align"),
        optionIcons: {
          start: "wf-align-left",
          center: "wf-align-center",
          end: "wf-align-right",
        },
      },
    },
    contentWidth: {
      type: "string",
      default: "contained",
      enum: VALID_CONTENT_WIDTHS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.section.content_width"),
      },
    },
    href: {
      type: "string",
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        group: "Link",
        label: i18n("blocks.builtin.section.href"),
        helpText: i18n("blocks.builtin.section.href_help"),
      },
    },
    linkLabel: {
      type: "string",
      default: "",
      ui: {
        group: "Link",
        label: i18n("blocks.builtin.section.link_label"),
        helpText: i18n("blocks.builtin.section.link_label_help"),
        conditional: { arg: "href", notEmpty: true },
      },
    },
  },
})
export default class Section extends Component {
  /**
   * Inline style for the section backdrop, emitted as CSS custom properties
   * the stylesheet consumes. A cover image (with optional dark variant) wins;
   * otherwise a gradient; a solid colour and a min-height layer in
   * independently. Painted via `background-image` (not an `<img>`) so it sits
   * behind the content without affecting layout.
   *
   * @returns {ReturnType<typeof trustHTML> | null}
   */
  get backdropStyle() {
    const decls = [];
    const image = this.args.background;
    if (image?.url) {
      decls.push(`--d-block-section-bg-image-light: ${cssUrl(image.url)}`);
      if (image.dark?.url) {
        decls.push(
          `--d-block-section-bg-image-dark: ${cssUrl(image.dark.url)}`
        );
      }
    } else if (this.args.gradient) {
      decls.push(`--d-block-section-bg-image-light: ${this.args.gradient}`);
    }
    if (this.args.backgroundColor) {
      decls.push(`--d-block-section-bg-color: ${this.args.backgroundColor}`);
    }
    if (this.args.minHeight) {
      decls.push(`--d-block-section-min-height: ${this.args.minHeight}`);
    }
    return decls.length ? trustHTML(decls.join("; ")) : null;
  }

  /**
   * Inline style for the colour overlay laid between the backdrop and the
   * content. Returns null (so the overlay element is dropped) unless both a
   * colour and a non-zero opacity are set.
   *
   * @returns {ReturnType<typeof trustHTML> | null}
   */
  get overlayStyle() {
    const color = this.args.overlayColor;
    const opacity = this.args.overlayOpacity ?? 0;
    if (!color || !opacity) {
      return null;
    }
    return trustHTML(`background-color: ${color}; opacity: ${opacity};`);
  }

  /**
   * BEM class list with the content alignment and width modifiers.
   *
   * @returns {string}
   */
  get className() {
    const align = VALID_CONTENT_ALIGNS.includes(this.args.contentAlign)
      ? this.args.contentAlign
      : "center";
    const width = VALID_CONTENT_WIDTHS.includes(this.args.contentWidth)
      ? this.args.contentWidth
      : "contained";
    return (
      `d-block-section d-block-section--align-${align} ` +
      `d-block-section--width-${width}`
    );
  }

  <template>
    <section class={{this.className}} style={{this.backdropStyle}}>
      {{! Always render the backdrop marker so edit tooling can anchor an
          image-drop target over it even with no background set. The empty
          modifier collapses it on the reader page; the drop-passive marker
          keeps it click-through behind the content. }}
      <div
        class="d-block-section__backdrop
          {{unless this.backdropStyle 'd-block-section__backdrop--empty'}}"
        data-block-arg="background"
        data-drop-passive
        data-drop-fills-block
      ></div>

      {{#if this.overlayStyle}}
        <div class="d-block-section__overlay" style={{this.overlayStyle}}></div>
      {{/if}}

      <div class="d-block-section__content">
        {{#each @children key="key" as |child|}}
          <child.Component />
        {{/each}}
      </div>

      {{#if @href}}
        <a
          class="d-block-stretched-link"
          href={{@href}}
          aria-label={{@linkLabel}}
          data-block-arg="href"
        ></a>
      {{/if}}
    </section>
  </template>
}

/**
 * Wraps a URL in CSS `url("...")` syntax with escaped quotes/backslashes so it
 * is safe to interpolate into an inline `style`. The URL comes from the
 * trusted upload pipeline; this only guards against a stray quote in a
 * CDN-rewritten path.
 *
 * @param {string} url
 * @returns {string}
 */
function cssUrl(url) {
  const escaped = url.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  return `url("${escaped}")`;
}
