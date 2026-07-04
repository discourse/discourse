// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
/** @type {import("discourse/ui-kit/d-decorated-html.gjs")} */
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import { i18n } from "discourse-i18n";

/**
 * Renders a chunk of pre-cooked / embed HTML (a provider embed snippet, an
 * oneboxed link's HTML, etc.) through the standard decorated-HTML renderer, so
 * registered decorators (oneboxes, hashtags, mentions) apply. The HTML is
 * author-supplied; since layouts are authored by staff, this carries the same
 * trust level as the HTML staff already write in themes.
 */
@block("embed", {
  thumbnail:
    /** @type {() => Promise<typeof import("discourse/blocks/thumbnails/embed.gjs")>} */ (
      () => import("discourse/blocks/thumbnails/embed")
    ),
  displayName: "Embed",
  icon: "code",
  category: "Content",
  description: "Embeds pre-cooked HTML (a provider snippet or oneboxed link).",
  args: {
    html: {
      type: "string",
      maxLength: 20000,
      ui: {
        control: "code",
        label: i18n("blocks.builtin.embed.html"),
        helpText: i18n("blocks.builtin.embed.html_help"),
      },
    },
  },
})
export default class Embed extends Component {
  /** @returns {ReturnType<typeof trustHTML>|null} */
  get safeHtml() {
    return this.args.html ? trustHTML(this.args.html) : null;
  }

  <template>
    <div class="d-block-embed" data-block-arg="html">
      {{#if this.safeHtml}}
        <DDecoratedHtml @html={{this.safeHtml}} />
      {{/if}}
    </div>
  </template>
}
