import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import ShareSource from "discourse/components/share-source";
import lazyHash from "discourse/helpers/lazy-hash";
import { afterRender } from "discourse/lib/decorators";
import { longDateNoYear } from "discourse/lib/formatter";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { showCreateInviteModal } from "discourse/lib/invite-modal";
import Sharing from "discourse/lib/sharing";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DCopyButton from "discourse/ui-kit/d-copy-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class ShareTopicModal extends Component {
  @service site;
  @service siteSettings;

  @tracked flash;
  @tracked flashType;

  constructor() {
    super(...arguments);
    this._showRestrictedGroupWarning();
    this._selectUrl();
  }

  get topic() {
    return this.args.model?.topic;
  }

  get post() {
    return this.args.model?.post;
  }

  get category() {
    return this.args.model?.category;
  }

  get allowInvites() {
    return this.args.model?.allowInvites;
  }

  get url() {
    if (this.post?.shareUrl) {
      return getAbsoluteURL(this.post?.shareUrl);
    } else if (this.topic?.shareUrl) {
      return getAbsoluteURL(this.topic?.shareUrl);
    }
  }

  get displayDate() {
    const date =
      this.post?.wiki && this.post?.last_wiki_edit
        ? this.post?.last_wiki_edit
        : this.post?.created_at;
    return longDateNoYear(new Date(date));
  }

  get sources() {
    const privateContext =
      this.siteSettings.login_required ||
      this.topic?.isPrivateMessage ||
      this.topic?.invisible ||
      this.topic?.category?.read_restricted;

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
    showCreateInviteModal(this, {
      model: {
        inviteToTopic: true,
        topics: [this.topic],
        topicId: this.topic.id,
        topicTitle: this.topic.title,
      },
    });
  }

  @action
  async replyAsNewTopic() {
    const post = this.post || (await this.topic.firstPost());
    const topicController = getOwner(this).lookup("controller:topic");
    topicController.actions.replyAsNewTopic.call(topicController, post);
    this.args.closeModal();
  }

  @afterRender
  _showRestrictedGroupWarning() {
    if (!this.category) {
      return;
    }

    Category.fetchVisibleGroups(this.category.id).then((result) => {
      if (result.groups.length > 0) {
        this.flash = i18n("topic.share.restricted_groups", {
          count: result.groups.length,
          groupNames: result.groups.join(", "),
        });
        this.flashType = "warning";
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

  <template>
    <DModal
      class="share-topic-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType={{this.flashType}}
      @subtitle={{if this.post this.displayDate}}
      @title={{if
        this.post
        (i18n "post.share.title" post_number=this.post.post_number)
        (i18n "topic.share.title")
      }}
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
              class="invite-link"
              id="invite-link"
              name="invite-link"
              readonly={{true}}
              size="200"
              @value={{this.url}}
            />
            <DCopyButton @ariaLabel="share.url" @selector="input.invite-link" />
          </div>
        </div>

        <div class="link-share-actions">
          <div class="sources">
            {{#each this.sources as |source|}}
              <ShareSource @action={{this.share}} @source={{source}} />
            {{/each}}

            {{#if this.allowInvites}}
              <DButton
                class="btn-default invite"
                @action={{this.inviteUsers}}
                @icon="user-plus"
                @label="topic.share.invite_users"
              />
            {{/if}}

            {{#if this.topic.details.can_reply_as_new_topic}}
              {{#if this.topic.isPrivateMessage}}
                <DButton
                  class="btn-default new-topic"
                  @action={{this.replyAsNewTopic}}
                  @ariaLabel="post.reply_as_new_private_message"
                  @icon="plus"
                  @label="user.new_private_message"
                  @title="post.reply_as_new_private_message"
                />
              {{else}}
                <DButton
                  class="btn-default new-topic"
                  @action={{this.replyAsNewTopic}}
                  @ariaLabel="post.reply_as_new_topic"
                  @icon="plus"
                  @label="topic.create"
                  @title="post.reply_as_new_topic"
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
