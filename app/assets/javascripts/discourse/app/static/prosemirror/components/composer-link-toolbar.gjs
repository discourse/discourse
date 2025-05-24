import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import InsertHyperlink from "discourse/components/modal/insert-hyperlink";
import icon from "discourse/helpers/d-icon";
import { clipboardCopy } from "discourse/lib/utilities";
import { getLinkify } from "discourse/static/prosemirror/lib/markdown-it";
import { i18n } from "discourse-i18n";

const AUTO_LINKS = ["autolink", "linkify"];

export default class ComposerLinkToolbar extends Component {
  @service toasts;
  @service modal;

  @action
  startEditing() {
    this.modal.show(InsertHyperlink, {
      model: {
        linkText: this.args.data.text,
        linkUrl: this.args.data.href,
        toolbarEvent: {
          addText: (text) => {
            const markdownLinkRegex = /\[(.*?)\]\((.*?)\)/;
            const [, linkText, linkUrl] = text.match(markdownLinkRegex);
            this.args.data.save({ text: linkText, href: linkUrl });
          },
        },
      },
    });
  }

  @action
  copy() {
    clipboardCopy(this.args.data.href);

    // TODO(renato) Show "Link copied!" inline
    this.toasts.success({
      duration: 1500,
      data: { message: i18n("composer.link_toolbar.link_copied") },
    });
  }

  get canUnlink() {
    // Unlinking autolinked links is cumbersome (relies on escaping),
    // it would be confusing to users so we just avoid it.
    return !AUTO_LINKS.includes(this.args.data.markup);
  }

  get canVisit() {
    // Follows the same logic from preview and doesn't show the button for invalid URLs
    return !!getLinkify().matchAtStart(this.args.data.href);
  }

  <template>
    <div role="toolbar" class="composer-link-toolbar">
      <DButton
        @icon="pen"
        class="btn-flat composer-link-toolbar__edit"
        title={{i18n "composer.link_toolbar.edit"}}
        @action={{this.startEditing}}
      />
      <DButton
        @icon="copy"
        class="btn-flat composer-link-toolbar__copy"
        title={{i18n "composer.link_toolbar.copy"}}
        @action={{this.copy}}
      />

      {{#if this.canUnlink}}
        <DButton
          @icon="link-slash"
          class="btn-flat composer-link-toolbar__unlink"
          title={{i18n "composer.link_toolbar.remove"}}
          @action={{@data.unlink}}
        />
      {{/if}}

      {{#if this.canVisit}}
        <div class="composer-link-toolbar__divider" />

        <a
          href={{@data.href}}
          target="_blank"
          rel="noopener noreferrer"
          class="composer-link-toolbar__visit"
          title={{i18n "composer.link_toolbar.visit"}}
        >
          {{icon "up-right-from-square"}}
        </a>
      {{/if}}
    </div>
  </template>
}
