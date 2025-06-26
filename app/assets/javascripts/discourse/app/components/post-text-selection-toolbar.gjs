import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { getAbsoluteURL } from "discourse/lib/get-url";
import Sharing from "discourse/lib/sharing";
import { clipboardCopy, postUrl } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class PostTextSelectionToolbar extends Component {
  @service currentUser;
  @service modal;
  @service site;
  @service siteSettings;
  @service appEvents;
  @service toasts;

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
  async copyQuoteToClipboard() {
    const text = await this.args.data.buildQuote();
    clipboardCopy(text);
    this.toasts.success({
      duration: "short",
      data: { message: i18n("post.quote_copied_to_clibboard") },
    });
    await this.args.data.hideToolbar();
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
    <div class={{concatClass "quote-button" "visible"}}>
      <div class="buttons">
        <PluginOutlet
          @name="post-text-buttons"
          @defaultGlimmer={{true}}
          @outletArgs={{lazyHash data=@data post=this.post}}
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
              {{on
                "click"
                (fn @data.toggleFastEdit this.quoteState @data.supportsFastEdit)
              }}
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
            @outletArgs={{lazyHash data=@data}}
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
                  @outletArgs={{lazyHash data=@data}}
                />
              </span>
            </span>
          {{/if}}
        </PluginOutlet>
      </div>

      <div class="extra">
        <PluginOutlet @name="quote-button-after" @connectorTagName="div" />
      </div>
    </div>
  </template>
}
