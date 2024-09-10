import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { inject as service } from "@ember/service";
import { and, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

export default class PostMenuRepliesButton extends Component {
  static shouldRender(post, context) {
    const replyCount = post.reply_count;

    if (!replyCount) {
      return false;
    }

    return !(
      replyCount === 1 &&
      context.replyDirectlyBelow &&
      context.suppressReplyDirectlyBelow
    );
  }

  @service site;

  get disabled() {
    return !!this.args.post.deleted;
  }

  get translatedTitle() {
    if (!this.args.context.filteredRepliesView) {
      return;
    }

    return this.args.context.repliesShown
      ? i18n("post.view_all_posts")
      : i18n("post.filtered_replies_hint", {
          count: this.args.post.reply_count,
        });
  }

  <template>
    {{#if @shouldRender}}
      <DButton
        class="show-replies btn-icon-text"
        ...attributes
        disabled={{this.disabled}}
        @action={{@action}}
        @ariaControls={{concat "embedded-posts__bottom--" @post.post_number}}
        @ariaExpanded={{and
          @context.repliesShown
          (not @context.filteredRepliesView)
        }}
        @ariaPressed={{if
          (not @context.filteredRepliesView)
          @context.repliesShown
        }}
        @translatedAriaLabel={{i18n
          "post.sr_expand_replies"
          count=this.replyCount
        }}
        @translatedLabel={{i18n
          (if this.site.mobileView "post.has_replies_count" "post.has_replies")
          count=@post.reply_count
        }}
        @translatedTitle={{this.translatedTitle}}
      >
        {{!--
               The icon on the replies button is aligned to the right
               To get the desired effect will use the {{yield}} in the DButton component to our advantage
               introducing manually the icon after the label
              --}}
        {{~icon (if @context.repliesShown "chevron-up" "chevron-down")~}}
      </DButton>
    {{/if}}
  </template>
}
