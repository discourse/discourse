import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { and, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { tracked } from "@glimmer/tracking";

export default class PostMenuRepliesButton extends Component {
  static extraControls = true;

  static shouldRender(args) {
    const replyCount = args.post.reply_count;

    if (!replyCount) {
      return false;
    }

    return !(
      replyCount === 1 &&
      args.state.replyDirectlyBelow &&
      args.state.suppressReplyDirectlyBelow
    );
  }

  @service site;

  // Processing lock, so repeated clicks are ignored
  @tracked _isProcessing = false;

  get disabled() {
    // while processing a toggle, disable the button to avoid duplicate clicks
    return !!this.args.post.deleted || this._isProcessing;
  }

  get translatedTitle() {
    if (!this.args.state.filteredRepliesView) {
      return;
    }

    return this.args.state.repliesShown
      ? i18n("post.view_all_posts")
      : i18n("post.filtered_replies_hint", {
          count: this.args.post.reply_count,
        });
  }

  // Wait until this.args.state.repliesShown changes from `initial`.
  // The lock will be released when the UI actually updates.
  _waitForRepliesShownChange(initial) {
    return new Promise((resolve) => {
      const check = () => {
        const current = this.args.state && this.args.state.repliesShown;
        if (current !== initial) {
          resolve();
        } else {
          this._pollTimer = setTimeout(check, 30);
        }
      };
      check();
    }).finally(() => {
      if (this._pollTimer) {
        clearTimeout(this._pollTimer);
        this._pollTimer = null;
      }
    });
  }

  // Sets a lock, calls the original action, and only releases
  // the lock after the repliesShown state actually changes.
  _debouncedToggle = async () => {
    if (this._isProcessing) {
      return;
    }

    const toggle =
      this.args.buttonActions && this.args.buttonActions.toggleReplies;
    if (typeof toggle !== "function") {
      return;
    }

    const initialRepliesShown =
      (this.args.state && this.args.state.repliesShown) ?? null;

    this._isProcessing = true;

    try {
      const result = toggle();

      // If the action returns a Promise, wait for it too, but still require the state change.
      const actionPromise =
        result && typeof result.then === "function" ? result : null;

      if (actionPromise) {
        await Promise.all([actionPromise, this._waitForRepliesShownChange(initialRepliesShown)]);
      } else {
        await this._waitForRepliesShownChange(initialRepliesShown);
      }
    } finally {
      this._isProcessing = false;
    }
  };

  <template>
    <DButton
      class="post-action-menu__show-replies show-replies btn-icon-text"
      ...attributes
      disabled={{this.disabled}}
      @action={{this._debouncedToggle}}
      @ariaControls={{concat "embedded-posts__bottom--" @post.post_number}}
      @ariaExpanded={{and @state.repliesShown (not @state.filteredRepliesView)}}
      @ariaPressed={{unless @state.filteredRepliesView @state.repliesShown}}
      @translatedAriaLabel={{i18n
        "post.sr_expand_replies"
        count=@post.reply_count
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
      {{~icon (if @state.repliesShown "chevron-up" "chevron-down")~}}
    </DButton>
  </template>
}
