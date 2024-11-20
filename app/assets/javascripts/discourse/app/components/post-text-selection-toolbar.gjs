import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import FastEdit from "discourse/components/fast-edit";
import FastEditModal from "discourse/components/modal/fast-edit";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import Sharing from "discourse/lib/sharing";
import {
  clipboardCopy,
  postUrl,
  setCaretPosition,
} from "discourse/lib/utilities";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import { i18n } from "discourse-i18n";

export function fixQuotes(str) {
  // u+201c, u+201d = “ ”
  // u+2018, u+2019 = ‘ ’
  return str.replace(/[\u201C\u201D]/g, '"').replace(/[\u2018\u2019]/g, "'");
}

export default class PostTextSelectionToolbar extends Component {
  @service currentUser;
  @service modal;
  @service site;
  @service siteSettings;
  @service appEvents;
  @service toasts;

  @tracked isFastEditing = false;

  appEventsListeners = modifier(() => {
    this.appEvents.on("quote-button:edit", this, "toggleFastEdit");

    return () => {
      this.appEvents.off("quote-button:edit", this, "toggleFastEdit");
    };
  });

  get topic() {
    return this.args.data.topic;
  }

  get quoteState() {
    return this.args.data.quoteState;
  }

  get post() {
    return this.topic.postStream.findLoadedPost(
      this.args.data.quoteState.postId
    );
  }

  get quoteSharingEnabled() {
    return (
      this.site.desktopView &&
      this.quoteSharingSources.length > 0 &&
      !this.topic.invisible &&
      !this.topic.category?.read_restricted &&
      (this.siteSettings.share_quote_visibility === "all" ||
        (this.siteSettings.share_quote_visibility === "anonymous" &&
          !this.currentUser))
    );
  }

  get quoteSharingSources() {
    return Sharing.activeSources(
      this.siteSettings.share_quote_buttons,
      this.siteSettings.login_required || this.topic.isPrivateMessage
    );
  }

  get quoteSharingShowLabel() {
    return this.quoteSharingSources.length > 1;
  }

  get shareUrl() {
    return getAbsoluteURL(
      postUrl(this.topic.slug, this.topic.id, this.post.post_number)
    );
  }

  get embedQuoteButton() {
    const canCreatePost = this.topic.details.can_create_post;
    const canReplyAsNewTopic = this.topic.details.can_reply_as_new_topic;

    return (
      (canCreatePost || canReplyAsNewTopic) &&
      this.currentUser?.get("user_option.enable_quoting")
    );
  }

  @action
  trapEvents(event) {
    event.stopPropagation();
  }

  @action
  async copyQuoteToClipboard() {
    const text = await this.args.data.buildQuote();
    clipboardCopy(text);
    this.toasts.success({
      duration: 3000,
      data: { message: i18n("post.quote_copied_to_clibboard") },
    });
    await this.args.data.hideToolbar();
  }

  @action
  async closeFastEdit() {
    this.isFastEditing = false;
    await this.args.data.hideToolbar();
  }

  @action
  async toggleFastEdit() {
    if (this.args.data.supportsFastEdit) {
      if (this.site.desktopView) {
        this.isFastEditing = !this.isFastEditing;
      } else {
        this.modal.show(FastEditModal, {
          model: {
            initialValue: this.args.data.quoteState.buffer,
            post: this.post,
          },
        });
        this.args.data.hideToolbar();
      }
    } else {
      const result = await ajax(`/posts/${this.post.id}`);

      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      let bestIndex = 0;
      const rows = result.raw.split("\n");

      // selecting even a part of the text of a list item will include
      // "* " at the beginning of the buffer, we remove it to be able
      // to find it in row
      const buffer = fixQuotes(
        this.args.data.quoteState.buffer.split("\n")[0].replace(/^\* /, "")
      );

      rows.some((row, index) => {
        if (row.length && row.includes(buffer)) {
          bestIndex = index;
          return true;
        }
      });

      this.args.data.editPost(this.post);

      document
        .querySelector("#reply-control")
        ?.addEventListener("transitionend", () => {
          const textarea = document.querySelector(".d-editor-input");
          if (!textarea || this.isDestroyed || this.isDestroying) {
            return;
          }

          // best index brings us to one row before as slice start from 1
          // we add 1 to be at the beginning of next line, unless we start from top
          setCaretPosition(
            textarea,
            rows.slice(0, bestIndex).join("\n").length + (bestIndex > 0 ? 1 : 0)
          );

          // ensures we correctly scroll to caret and reloads composer
          // if we do another selection/edit
          textarea.blur();
          textarea.focus();
        });

      this.args.data.hideToolbar();
      return;
    }
  }

  @action
  share(source) {
    Sharing.shareSource(source, {
      url: this.shareUrl,
      title: this.topic.title,
      quote: window.getSelection().toString(),
    });
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    {{! template-lint-disable no-pointer-down-event-binding }}
    <div
      {{on "mousedown" this.trapEvents}}
      {{on "mouseup" this.trapEvents}}
      class={{concatClass
        "quote-button"
        "visible"
        (if this.isFastEditing "fast-editing")
      }}
      {{this.appEventsListeners}}
    >
      <div class="buttons">
        <PluginOutlet
          @name="post-text-buttons"
          @defaultGlimmer={{true}}
          @outletArgs={{hash data=@data post=this.post}}
        >
          {{#if this.embedQuoteButton}}
            <DButton
              @icon="quote-left"
              @label="post.quote_reply"
              @title="post.quote_reply_shortcut"
              class="btn-flat insert-quote"
              @action={{@data.insertQuote}}
            />
          {{/if}}

          {{#if @data.canEditPost}}
            <DButton
              @icon="pencil"
              @label="post.quote_edit"
              @title="post.quote_edit_shortcut"
              class="btn-flat quote-edit-label"
              {{on "click" this.toggleFastEdit}}
            />
          {{/if}}

          {{#if @data.canCopyQuote}}
            <DButton
              @icon="copy"
              @label="post.quote_copy"
              @title="post.quote_copy"
              class="btn-flat copy-quote"
              {{on "click" this.copyQuoteToClipboard}}
            />
          {{/if}}

          <PluginOutlet
            @name="quote-share-buttons-before"
            @connectorTagName="span"
            @outletArgs={{hash data=@data}}
          />

          {{#if this.quoteSharingEnabled}}
            <span class="quote-sharing">
              {{#if this.quoteSharingShowLabel}}
                <DButton
                  @icon="share"
                  @label="post.quote_share"
                  class="btn-flat quote-share-label"
                />
              {{/if}}

              <span class="quote-share-buttons">
                {{#each this.quoteSharingSources as |source|}}
                  <DButton
                    @action={{fn this.share source}}
                    @translatedTitle={{source.title}}
                    @icon={{source.icon}}
                    class="btn-flat"
                  />
                {{/each}}

                <PluginOutlet
                  @name="quote-share-buttons-after"
                  @connectorTagName="span"
                  @outletArgs={{hash data=@data}}
                />
              </span>
            </span>
          {{/if}}
        </PluginOutlet>
      </div>

      <div class="extra">
        {{#if this.isFastEditing}}
          <FastEdit
            @initialValue={{@data.quoteState.buffer}}
            @post={{this.post}}
            @close={{this.closeFastEdit}}
          />
        {{/if}}

        <PluginOutlet @name="quote-button-after" @connectorTagName="div" />
      </div>
    </div>
  </template>
}
