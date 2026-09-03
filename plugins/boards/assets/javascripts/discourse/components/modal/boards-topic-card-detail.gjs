import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import renderTags from "discourse/lib/render-tags";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Topic from "discourse/models/topic";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import DModal from "discourse/ui-kit/d-modal";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { columnColorVariable } from "../../lib/boards-column-helpers";

export default class BoardsTopicCardDetail extends Component {
  @service currentUser;

  @tracked loading = true;
  @tracked cooked = null;
  @tracked loadError = false;

  constructor() {
    super(...arguments);
    this.loadFirstPost();
  }

  get topic() {
    return this.args.model.card.topic;
  }

  get topicUrl() {
    return Topic.create(this.topic).lastUnreadUrl;
  }

  get topicTitle() {
    return trustHTML(
      emojiUnescape(escapeExpression(this.args.model.card.fancyTitle || ""))
    );
  }

  get category() {
    if (!this.topic?.category_id) {
      return null;
    }
    return Category.findById(this.topic.category_id);
  }

  get allAssignedUsers() {
    if (this.topic?.all_assigned_users?.length) {
      return this.topic.all_assigned_users;
    }
    if (this.topic?.assigned_to_user) {
      return [this.topic.assigned_to_user];
    }
    return [];
  }

  get assignedGroupName() {
    return this.topic?.assigned_to_group?.name;
  }

  get replyCount() {
    const count = this.topic?.posts_count;
    return count > 1 ? count - 1 : 0;
  }

  get lastPoster() {
    return this.topic?.last_poster;
  }

  get columnData() {
    const { columnTitle, columnIcon, columnColor } = this.args.model;
    if (!columnTitle) {
      return null;
    }
    return { title: columnTitle, icon: columnIcon, color: columnColor };
  }

  get tagsHtml() {
    if (!this.topic?.tags?.length) {
      return null;
    }
    return renderTags(null, { tags: this.topic.tags });
  }

  async loadFirstPost() {
    try {
      const post = await ajax(
        `/posts/by_number/${this.args.model.card.topic_id}/1.json`
      );
      this.cooked = post.cooked;
    } catch {
      this.loadError = true;
    } finally {
      this.loading = false;
    }
  }

  @action
  viewCard() {
    if (!this.currentUser) {
      return;
    }

    ajax(
      `/boards/api/boards/${this.args.model.card.board_id}/cards/${this.args.model.card.id}/view`,
      { method: "POST" }
    ).catch(() => {
      // No error message should be shown if this fails,
      // it's purely for history logging.
    });
  }

  <template>
    <DModal
      @title={{this.topicTitle}}
      @closeModal={{@closeModal}}
      class="discourse-boards-topic-card-detail-modal"
      {{didInsert this.viewCard}}
    >
      <:body>

        {{#if
          (or
            this.category
            this.tagsHtml
            this.allAssignedUsers.length
            this.columnData
          )
        }}
          <div class="discourse-boards-topic-card-detail__meta">
            {{#if this.category}}
              {{dCategoryBadge this.category link=true}}
            {{/if}}
            {{#if this.tagsHtml}}
              <span class="discourse-boards-topic-card-detail__tags">
                {{trustHTML this.tagsHtml}}
              </span>
            {{/if}}
            {{#if this.allAssignedUsers.length}}
              <span class="discourse-boards-topic-card-detail__assigned">
                {{dIcon "user-plus"}}
                {{#each this.allAssignedUsers as |user|}}
                  <a
                    href="/u/{{user.username}}/activity/assigned"
                    class="discourse-boards-topic-card-detail__username"
                  >{{user.username}}</a>
                {{/each}}
              </span>
            {{else if this.assignedGroupName}}
              <span class="discourse-boards-topic-card-detail__assigned">
                {{dIcon "group-plus"}}
                <span
                  class="discourse-boards-topic-card-detail__username"
                >{{this.assignedGroupName}}</span>
              </span>
            {{/if}}
            {{#if this.columnData}}
              <span
                class="discourse-boards-column__title"
                style={{columnColorVariable this.columnData.color}}
              >
                {{#if this.columnData.icon}}{{dIcon
                    this.columnData.icon
                  }}{{/if}}
                {{this.columnData.title}}
              </span>
            {{/if}}
          </div>
        {{/if}}

        <DConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.loadError}}
            <div class="discourse-boards-topic-card-detail__error">
              {{i18n "boards.board.topic_load_error"}}
            </div>
          {{else}}
            <div class="discourse-boards-topic-card-detail__cooked">
              <DDecoratedHtml
                @html={{trustHTML this.cooked}}
                @className="cooked"
              />
            </div>
          {{/if}}
        </DConditionalLoadingSpinner>

        {{#if this.replyCount}}
          <div class="discourse-boards-topic-card-detail__stats">
            {{dIcon "comments"}}
            {{i18n "boards.board.topic_reply_count" count=this.replyCount}}
            {{#if this.lastPoster}}
              <span
                class="discourse-boards-topic-card-detail__separator"
              >·</span>
              {{i18n
                "boards.board.topic_last_reply"
                username=this.lastPoster.username
              }}
              {{dFormatDate this.topic.bumped_at format="medium"}}
            {{/if}}
          </div>
        {{/if}}
      </:body>
      <:footer>
        <DButton
          @href={{this.topicUrl}}
          class="btn-primary"
          @action={{this.viewTopic}}
          @icon="up-right-from-square"
          @label="boards.board.view_topic"
        />
      </:footer>
    </DModal>
  </template>
}
