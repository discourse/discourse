import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import TopicTimeline from "discourse/components/topic-timeline";
import { extractError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class ChangeReplyTo extends Component {
  @tracked selectedPost = null;
  @tracked flash = null;

  noop = () => {};

  get topic() {
    return this.args.model.topic;
  }

  get editingPostNumber() {
    return this.args.model.editingPostNumber;
  }

  get canSubmit() {
    return (
      !!this.selectedPost &&
      this.selectedPost.post_number < this.editingPostNumber
    );
  }

  get canRemove() {
    return !!this.args.model.currentPostNumber;
  }

  get initialEnteredIndex() {
    const postNumber = this.args.model.currentPostNumber;
    if (!postNumber) {
      return 0;
    }
    const postStream = this.topic?.postStream;
    const post = postStream?.postForPostNumber?.(postNumber);
    if (!post) {
      return 0;
    }
    // `TopicTimeline` treats `@enteredIndex` as 0-based (see how its
    // `prevEvent.postIndex - 1` branch maps a 1-based event index back
    // down), while `progressIndexOfPost` returns 1-based. Subtract one
    // so the scrubber lands exactly on the current target.
    return Math.max(0, postStream.progressIndexOfPost(post) - 1);
  }

  @action
  async handleJumpToIndex(index) {
    await this.captureSelectionForIndex(index);
  }

  @action
  async handleJumpTop() {
    await this.captureSelectionForIndex(1);
  }

  @action
  async handleJumpBottom() {
    const total = this.topic?.postStream?.filteredPostsCount;
    if (total) {
      await this.captureSelectionForIndex(total);
    }
  }

  async captureSelectionForIndex(timelineIndex) {
    const postStream = this.topic?.postStream;
    if (!postStream || !timelineIndex) {
      return;
    }

    try {
      let post;
      if (postStream.isMegaTopic) {
        // On mega topics the timeline's `current` / jump callbacks are
        // post numbers, not stream positions — see `filteredPostsCount`.
        post =
          postStream.postForPostNumber(timelineIndex) ||
          (await postStream.loadPostByPostNumber(timelineIndex));
      } else {
        const postId = postStream.stream[timelineIndex - 1];
        if (!postId) {
          return;
        }
        post =
          postStream.findLoadedPost(postId) ||
          (await postStream.loadPost(postId));
      }

      if (!post) {
        return;
      }
      if (post.post_number >= this.editingPostNumber) {
        this.flash = i18n("composer.change_reply_to.invalid_target");
        this.selectedPost = null;
        return;
      }
      this.flash = null;
      this.selectedPost = post;
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  @action
  submit() {
    if (!this.canSubmit) {
      return;
    }
    this.args.model.onSelect(this.selectedPost);
    this.args.closeModal();
  }

  @action
  remove() {
    this.args.model.onSelect(null);
    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "composer.change_reply_to.title"}}
      @flash={{this.flash}}
      class="change-reply-to-modal"
    >
      <:body>
        {{#if this.selectedPost}}
          <p class="change-reply-to-modal__selection">
            {{i18n
              "composer.change_reply_to.current_selection"
              post_number=this.selectedPost.post_number
              username=this.selectedPost.username
            }}
          </p>
        {{else}}
          <p class="change-reply-to-modal__hint">
            {{i18n "composer.change_reply_to.hint"}}
          </p>
        {{/if}}

        <TopicTimeline
          @model={{this.topic}}
          @fullscreen={{true}}
          @enteredIndex={{this.initialEnteredIndex}}
          @jumpTop={{this.handleJumpTop}}
          @jumpBottom={{this.handleJumpBottom}}
          @jumpEnd={{this.handleJumpBottom}}
          @jumpToIndex={{this.handleJumpToIndex}}
          @jumpToPostPrompt={{this.noop}}
          @replyToPost={{this.noop}}
          @showTopReplies={{this.noop}}
          @toggleMultiSelect={{this.noop}}
          @showTopicSlowModeUpdate={{this.noop}}
          @deleteTopic={{this.noop}}
          @recoverTopic={{this.noop}}
          @toggleClosed={{this.noop}}
          @toggleArchived={{this.noop}}
          @toggleVisibility={{this.noop}}
          @showTopicTimerModal={{this.noop}}
          @showFeatureTopic={{this.noop}}
          @showChangeTimestamp={{this.noop}}
          @resetBumpDate={{this.noop}}
          @convertToPublicTopic={{this.noop}}
          @convertToPrivateMessage={{this.noop}}
        />
      </:body>
      <:footer>
        <DButton
          @action={{this.submit}}
          @label="composer.change_reply_to.submit"
          @disabled={{not this.canSubmit}}
          class="btn-primary"
        />
        {{#if this.canRemove}}
          <DButton
            @action={{this.remove}}
            @label="composer.change_reply_to.remove"
            class="btn-danger"
          />
        {{/if}}
        <DButton @action={{@closeModal}} @label="cancel" />
      </:footer>
    </DModal>
  </template>
}
