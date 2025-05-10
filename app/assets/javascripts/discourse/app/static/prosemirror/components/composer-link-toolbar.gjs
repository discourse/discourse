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
    // TODO Show "Link copied!" inline
    this.toasts.success({
      duration: 1500,
      data: { message: i18n("post.controls.link_copied") },
    });
  }

  get canUnlink() {
    return !AUTO_LINKS.includes(this.args.data.markup);
  }

  get canVisit() {
    return !!getLinkify().matchAtStart(this.args.data.href);
  }

  <template>
    <div role="toolbar" class="composer-link-toolbar">
      <DButton @icon="pen" class="btn-flat" @action={{this.startEditing}} />
      <DButton @icon="copy" class="btn-flat" @action={{this.copy}} />

      {{#if this.canUnlink}}
        <DButton @icon="link-slash" class="btn-flat" @action={{@data.unlink}} />
      {{/if}}

      {{#if this.canVisit}}
        <div class="composer-link-toolbar__divider" />

        <a
          href={{@data.href}}
          target="_blank"
          rel="noopener noreferrer"
          class="composer-link-toolbar__visit"
        >
          {{icon "up-right-from-square"}}
        </a>
      {{/if}}
    </div>
  </template>
}
