import Component, { Input } from "@ember/component";
import { action } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import CopyButton from "discourse/components/copy-button";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import CreateInvite from "discourse/components/modal/create-invite";
import PluginOutlet from "discourse/components/plugin-outlet";
import ShareSource from "discourse/components/share-source";
import lazyHash from "discourse/helpers/lazy-hash";
import discourseComputed, { afterRender } from "discourse/lib/decorators";
import { longDateNoYear } from "discourse/lib/formatter";
import { getAbsoluteURL } from "discourse/lib/get-url";
import Sharing from "discourse/lib/sharing";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

export default class ShareTopicModal extends Component {
  @service modal;

  @readOnly("model.topic") topic;
  @readOnly("model.post") post;
  @readOnly("model.category") category;
  @readOnly("model.allowInvites") allowInvites;

  didInsertElement() {
    this._showRestrictedGroupWarning();
    this._selectUrl();
    super.didInsertElement();
  }

  @afterRender
  _showRestrictedGroupWarning() {
    if (!this.category) {
      return;
    }

    Category.fetchVisibleGroups(this.category.id).then((result) => {
      if (result.groups.length > 0) {
        this.setProperties({
          flash: i18n("topic.share.restricted_groups", {
            count: result.groups.length,
            groupNames: result.groups.join(", "),
          }),
          flashType: "warning",
        });
      }
    });
  }

  @afterRender
  _selectUrl() {
    const input = document.querySelector("input.invite-link");
    if (input && this.site.desktopView) {
      // if the input is auto-focused on mobile, iOS requires two taps of the copy button
      input.setSelectionRange(0, this.url.length);
      input.focus();
    }
  }

  @discourseComputed("post.shareUrl", "topic.shareUrl")
  url(postUrl, topicUrl) {
    if (postUrl) {
      return getAbsoluteURL(postUrl);
    } else if (topicUrl) {
      return getAbsoluteURL(topicUrl);
    }
  }

  @discourseComputed("post.created_at", "post.wiki", "post.last_wiki_edit")
  displayDate(createdAt, wiki, lastWikiEdit) {
    const date = wiki && lastWikiEdit ? lastWikiEdit : createdAt;
    return longDateNoYear(new Date(date));
  }

  @discourseComputed(
    "topic.{isPrivateMessage,invisible,category.read_restricted}"
  )
  sources(topic) {
    const privateContext =
      this.siteSettings.login_required ||
      topic?.isPrivateMessage ||
      topic?.invisible ||
      topic?.category?.read_restricted;

    return Sharing.activeSources(this.siteSettings.share_links, privateContext);
  }

  @action
  share(source) {
    Sharing.shareSource(source, {
      title: this.topic.title,
      url: this.url,
    });
  }

  @action
  inviteUsers() {
    this.modal.show(CreateInvite, {
      model: {
        inviteToTopic: true,
        topics: [this.topic],
        topicId: this.topic.id,
        topicTitle: this.topic.title,
      },
    });
  }

  @action
  replyAsNewTopic() {
    const postStream = this.topic.postStream;
    const postId = this.post?.id || postStream.findPostIdForPostNumber(1);
    const post = postStream.findLoadedPost(postId);
    const topicController = getOwner(this).lookup("controller:topic");
    topicController.actions.replyAsNewTopic.call(topicController, post);
    this.closeModal();
  }

  <template>
    <DModal
      @title={{if
        this.post
        (i18n "post.share.title" post_number=this.post.post_number)
        (i18n "topic.share.title")
      }}
      @subtitle={{if this.post this.displayDate}}
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType={{this.flashType}}
      class="share-topic-modal"
    >
      <form>
        <div class="input-group invite-link">
          <label for="invite-link">
            {{if
              this.post
              (i18n "post.share.instructions" post_number=this.post.post_number)
              (i18n "topic.share.instructions")
            }}
          </label>
          <div class="link-share-container">
            <Input
              id="invite-link"
              name="invite-link"
              class="invite-link"
              @value={{this.url}}
              readonly={{true}}
              size="200"
            />
            <CopyButton @selector="input.invite-link" @ariaLabel="share.url" />
          </div>
        </div>

        <div class="link-share-actions">
          <div class="sources">
            {{#each this.sources as |source|}}
              <ShareSource @source={{source}} @action={{this.share}} />
            {{/each}}

            {{#if this.allowInvites}}
              <DButton
                @label="topic.share.invite_users"
                @icon="user-plus"
                @action={{this.inviteUsers}}
                class="btn-default invite"
              />
            {{/if}}

            {{#if this.topic.details.can_reply_as_new_topic}}
              {{#if this.topic.isPrivateMessage}}
                <DButton
                  @action={{this.replyAsNewTopic}}
                  @icon="plus"
                  @ariaLabel="post.reply_as_new_private_message"
                  @title="post.reply_as_new_private_message"
                  @label="user.new_private_message"
                  class="btn-default new-topic"
                />
              {{else}}
                <DButton
                  @action={{this.replyAsNewTopic}}
                  @icon="plus"
                  @ariaLabel="post.reply_as_new_topic"
                  @title="post.reply_as_new_topic"
                  @label="topic.create"
                  class="btn-default new-topic"
                />
              {{/if}}
            {{/if}}
            <PluginOutlet
              @name="share-topic-sources"
              @outletArgs={{lazyHash topic=this.topic post=this.post}}
            />
          </div>
        </div>
      </form>
    </DModal>
  </template>
}
