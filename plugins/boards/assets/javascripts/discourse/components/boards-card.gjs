import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import TopicStatus from "discourse/components/topic-status";
import DMenu from "discourse/float-kit/components/d-menu";
import renderTags from "discourse/lib/render-tags";
import { emojiUnescape } from "discourse/lib/text";
import DiscourseURL from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import { not, or } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { renderAvatar } from "discourse/ui-kit/helpers/d-user-avatar";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import { i18n } from "discourse-i18n";
import { loadCategory } from "../lib/boards-categories";
import { boardsBoardUrl, boardsCardUrl } from "../lib/boards-urls";
import AutoLinkedText from "./auto-linked-text";
import BoardsCardDetailModal from "./modal/boards-card-detail";
import BoardsFloaterAssignModal from "./modal/boards-floater-assign";
import BoardsTopicCardDetailModal from "./modal/boards-topic-card-detail";

export function shouldInsertSourceDropIndicator(root = document) {
  return !root.querySelector(
    ".discourse-boards-column__drop-indicator:not(.discourse-boards-column__drop-indicator--source)"
  );
}

export default class BoardsCard extends Component {
  @service currentUser;
  @service modal;
  @service siteSettings;

  @tracked dragging = false;

  /**
   * Links and images inside the card start their own native drag, which no
   * column accepts. Tags and badges are rendered HTML that can't bind
   * `draggable`, so it is switched off on whatever is pressed.
   */
  suppressNestedNativeDrag = modifier((element) => {
    const onPointerDown = (event) => {
      if (!element.hasAttribute("data-drag-source")) {
        return;
      }
      const nested = event.target.closest?.("a, img");
      if (nested && element.contains(nested)) {
        nested.draggable = false;
      }
    };

    element.addEventListener("pointerdown", onPointerDown, { capture: true });
    return () =>
      element.removeEventListener("pointerdown", onPointerDown, {
        capture: true,
      });
  });

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.dragging) {
      this.#removeDropIndicators();
    }
  }

  get isTopicCard() {
    return this.args.card.card_type === "topic" && this.args.card.topic;
  }

  get topic() {
    return this.args.card.topic;
  }

  get cardTitle() {
    return this.args.card.fancyTitle;
  }

  get renderedTopicTitle() {
    return trustHTML(emojiUnescape(escapeExpression(this.cardTitle || "")));
  }

  get inlineOneboxData() {
    const data = this.args.card.inline_onebox_data;
    return data?.url && data?.title ? data : null;
  }

  get columnTagNames() {
    return new Set(
      (this.args.columnTags || []).map((tag) => tag.toLowerCase())
    );
  }

  get visibleFloaterTags() {
    const tags = this.args.card.tags || [];
    if (!tags.length) {
      return [];
    }

    const columnTagNames = this.columnTagNames;
    return tags.filter((tag) => {
      const name = typeof tag === "string" ? tag : tag.name;
      return !columnTagNames.has(name?.toLowerCase());
    });
  }

  get tagsHtml() {
    if (this.isTopicCard) {
      if (!this.args.board.show_tags || !this.topic?.tags) {
        return null;
      }

      const columnTagNames = this.columnTagNames;
      const filtered = this.topic.tags.filter(
        (tag) => !columnTagNames.has(tag.toLowerCase())
      );

      return filtered.length ? renderTags(null, { tags: filtered }) : null;
    }

    const tags = this.visibleFloaterTags;
    return tags.length ? renderTags(null, { tags }) : null;
  }

  get categoryId() {
    return this.args.allSameCategory ? null : this.topic?.category_id;
  }

  get isDetailed() {
    return this.args.board.card_style === "detailed";
  }

  get showImage() {
    return this.args.board.show_topic_thumbnail && this.topic?.image_url;
  }

  get allAssignedUsers() {
    if (this.topic?.all_assigned_users?.length) {
      return this.topic.all_assigned_users;
    }
    if (this.topic?.assigned_to_user) {
      return [this.topic.assigned_to_user];
    }
    const floaterAssignment = this.args.card.assigned_to;
    if (
      !this.isTopicCard &&
      this.siteSettings.assign_enabled &&
      floaterAssignment?.type === "User"
    ) {
      return [floaterAssignment];
    }
    return [];
  }

  get assignedGroup() {
    if (!this.siteSettings.assign_enabled) {
      return null;
    }
    const floaterAssignment = this.args.card.assigned_to;
    if (!this.isTopicCard && floaterAssignment?.type === "Group") {
      return floaterAssignment;
    }
    return null;
  }

  get assignedAvatarHtml() {
    const users = this.allAssignedUsers;
    if (!users.length) {
      return null;
    }
    return users
      .map((user) =>
        renderAvatar(user, {
          avatarTemplatePath: "avatar_template",
          usernamePath: "username",
          imageSize: "tiny",
        })
      )
      .join("");
  }

  get lastPosterUsername() {
    if (this.isTopicCard) {
      return this.topic?.last_poster?.username;
    }
    return this.args.card.created_by?.username;
  }

  get activityDate() {
    return (
      this.args.card.recency_at ||
      (this.isTopicCard ? this.topic?.bumped_at : this.args.card.created_at)
    );
  }

  get topicStatusModel() {
    if (!this.isTopicCard) {
      return null;
    }
    return { closed: this.topic?.closed };
  }

  get canShowActions() {
    return this.args.board.canWrite;
  }

  get showAssignButton() {
    if (!this.isTopicCard) {
      return this.canAssign;
    }

    return this.canAssign && !this.topicStatusModel?.closed;
  }

  get canAssign() {
    return (
      !this.args.board.archived &&
      this.siteSettings.assign_enabled &&
      this.currentUser?.can_assign &&
      (this.isTopicCard || this.args.board.canWrite)
    );
  }

  get isAssigned() {
    return (
      this.allAssignedUsers.length > 0 ||
      !!this.topic?.assigned_to_group ||
      !!this.assignedGroup
    );
  }

  get topicAssignments() {
    return (this.topic?.assignments || []).map((a) => ({
      ...a,
      unassignLabel: a.username
        ? a.target_type === "Post"
          ? i18n("boards.board.unassign_from_post", {
              username: a.username,
              post_number: a.post_number,
            })
          : i18n("boards.board.unassign_from_topic", {
              username: a.username,
            })
        : i18n("boards.board.unassign_group_from_topic", {
            group_name: a.group_name,
          }),
    }));
  }

  @action
  openDetailModal() {
    const board = this.args.board;
    const boardUrl = boardsBoardUrl(board);
    const cardUrlPath = boardsCardUrl(board, this.args.card.id);

    DiscourseURL.replaceState(cardUrlPath);

    this.modal
      .show(BoardsCardDetailModal, {
        model: {
          card: this.args.card,
          board: this.args.board,
          onUpdateCard: this.args.onUpdateCard,
        },
      })
      .finally(() => {
        if (!this.isDestroying) {
          DiscourseURL.replaceState(boardUrl);
        }
      });
  }

  @action
  openTopicDetailModal() {
    const board = this.args.board;
    const boardUrl = boardsBoardUrl(board);
    const cardUrlPath = boardsCardUrl(board, this.args.card.id);
    let navigatedAway = false;

    DiscourseURL.replaceState(cardUrlPath);

    this.modal
      .show(BoardsTopicCardDetailModal, {
        model: {
          card: this.args.card,
          columnTitle: this.args.columnTitle,
          columnIcon: this.args.columnIcon,
          columnColor: this.args.columnColor,
          onNavigateAway: (url) => {
            navigatedAway = true;
            DiscourseURL.routeTo(url);
          },
        },
      })
      .finally(() => {
        if (!navigatedAway && !this.isDestroying) {
          DiscourseURL.replaceState(boardUrl);
        }
      });
  }

  @action
  handleAssign(event) {
    event?.stopPropagation();
    if (this.isTopicCard) {
      const taskActions = getOwner(this).lookup("service:task-actions");
      taskActions.showAssignModal(this.topic, {
        isAssigned: this.isAssigned,
        targetType: "Topic",
        onSuccess: () => this.args.onRefreshBoard?.(),
      });
    } else {
      this.#openFloaterAssignModal();
    }
  }

  @action
  editAssignments(close) {
    close?.();
    if (this.isTopicCard) {
      const taskActions = getOwner(this).lookup("service:task-actions");
      taskActions.showAssignModal(this.topic, {
        isAssigned: this.isAssigned,
        targetType: "Topic",
        onSuccess: () => this.args.onRefreshBoard?.(),
      });
    } else {
      this.#openFloaterAssignModal();
    }
  }

  @action
  async unassignFromMenu(close) {
    close?.();
    if (this.isTopicCard) {
      const taskActions = getOwner(this).lookup("service:task-actions");
      await taskActions.unassign(this.topic.id, "Topic");
    } else {
      await this.args.onUpdateCard?.(this.args.card.id, {
        assigned_to_name: null,
      });
    }
    this.args.onRefreshBoard?.();
  }

  @action
  async unassignTarget(assignment, close) {
    close?.();
    const taskActions = getOwner(this).lookup("service:task-actions");
    await taskActions.unassign(assignment.target_id, assignment.target_type);
    this.args.onRefreshBoard?.();
  }

  @action
  onCardClick(event) {
    if (
      event.target.closest(".discourse-boards-card__actions-trigger") ||
      event.target.closest(".discourse-boards-card__assign-btn") ||
      event.target.closest("[data-content]") ||
      event.target.closest("a")
    ) {
      return;
    }
    if (this.isTopicCard) {
      this.openTopicDetailModal();
    } else {
      this.openDetailModal();
    }
  }

  @action
  onCardKeydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.onCardClick(event);
    }
  }

  @action
  removeCard() {
    this.args.onDeleteCard(this.args.card.id);
  }

  @action
  dragStart({ source }) {
    const cardElement = source.element;
    const cardHeight = cardElement.getBoundingClientRect().height;

    this.args.onDragStart({
      cardId: this.args.card.id,
      topicId: this.args.card.topic_id,
      fromColumnId: this.args.card.column_id,
      cardHeight,
      hasPlacedIndicator: false,
    });

    if (shouldInsertSourceDropIndicator()) {
      this.#insertSourceDropIndicator(cardElement, cardHeight);
    }
    this.dragging = true;
  }

  @action
  dragEnd() {
    this.args.onDragEnd?.(this.args.card.id);
    if (!this.args.isPendingDrop) {
      this.#removeDropIndicators();
    }
    this.dragging = false;
  }

  #openFloaterAssignModal() {
    const assignedTo = this.args.card.assigned_to;
    this.modal.show(BoardsFloaterAssignModal, {
      model: {
        currentAssignee: assignedTo?.username || assignedTo?.name || null,
        onSave: async (name) => {
          await this.args.onUpdateCard?.(this.args.card.id, {
            assigned_to_name: name,
          });
          this.args.onRefreshBoard?.();
        },
      },
    });
  }

  #insertSourceDropIndicator(cardElement, cardHeight) {
    const cardsContainer = cardElement.closest(
      ".discourse-boards-column__cards"
    );
    if (!cardsContainer) {
      return;
    }

    this.#removeDropIndicators();

    const indicator = document.createElement("div");
    indicator.className =
      "discourse-boards-column__drop-indicator discourse-boards-column__drop-indicator--source";
    indicator.style.height = `${cardHeight}px`;

    cardsContainer.insertBefore(indicator, cardElement);
  }

  #removeDropIndicators() {
    document
      .querySelectorAll(".discourse-boards-column__drop-indicator")
      .forEach((indicator) => indicator.remove());
  }

  <template>
    {{! eslint-disable ember/template-no-nested-interactive }}
    <div
      class={{dConcatClass
        "discourse-boards-card"
        (if (or this.dragging @isPendingDrop) "discourse-boards-card--dragging")
        (unless this.isTopicCard "discourse-boards-card--floater")
        (if @isDropHighlighted "discourse-boards-card--drop-highlighted")
        (if @isLinkHighlighted "discourse-boards-card--link-highlighted")
      }}
      data-card-id={{@card.id}}
      data-topic-id={{@card.topic_id}}
      role="button"
      tabindex="0"
      {{dDragAndDropSource
        type="boards-card"
        data=(hash cardId=@card.id fromColumnId=@card.column_id)
        disabled=(not @board.canWrite)
        onDragEnd=this.dragEnd
        onDragStart=this.dragStart
      }}
      {{this.suppressNestedNativeDrag}}
      {{on "click" this.onCardClick}}
      {{on "keydown" this.onCardKeydown}}
    >
      <div class="discourse-boards-card__row discourse-boards-card__title-row">

        {{#if this.isTopicCard}}
          <span
            class="discourse-boards-card__title discourse-boards-card__title--topic"
          >
            {{#if this.topicStatusModel}}
              <TopicStatus @topic={{this.topicStatusModel}} />
            {{/if}}
            {{this.renderedTopicTitle}}
          </span>
        {{else}}
          <span class="discourse-boards-card__title">
            {{#if this.inlineOneboxData}}
              <a
                class={{dConcatClass
                  "inline-onebox"
                  this.inlineOneboxData.css_class
                }}
                href={{this.inlineOneboxData.url}}
                rel="noopener noreferrer"
                target="_blank"
              >{{this.inlineOneboxData.title}}</a>
            {{else}}
              <AutoLinkedText @text={{this.cardTitle}} />
            {{/if}}
          </span>
        {{/if}}
        {{#if this.canShowActions}}
          <DMenu
            @icon="ellipsis"
            @identifier="boards-card-actions"
            @triggerClass="btn-flat btn-small discourse-boards-card__actions-trigger"
          >
            <:content>
              <DDropdownMenu as |dropdown|>
                {{#unless this.isTopicCard}}
                  <dropdown.item>
                    <DButton
                      class="btn-transparent"
                      @action={{this.openDetailModal}}
                      @icon="pencil"
                      @label="edit"
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      class="btn-transparent"
                      @action={{@onPromoteToTopic}}
                      @icon="plus"
                      @label="boards.board.new_topic"
                    />
                  </dropdown.item>
                {{/unless}}
                <dropdown.item>
                  <DButton
                    class="btn-transparent btn-danger"
                    @action={{this.removeCard}}
                    @icon="trash-can"
                    @label="boards.board.remove_card"
                  />
                </dropdown.item>
              </DDropdownMenu>
            </:content>
          </DMenu>
        {{/if}}
        {{#unless this.isDetailed}}
          {{#if this.activityDate}}
            <span class="discourse-boards-card__date">
              {{dFormatDate this.activityDate format="tiny" noTitle="true"}}
            </span>
          {{/if}}
        {{/unless}}
      </div>

      {{#if this.tagsHtml}}
        <div class="discourse-boards-card__row discourse-boards-card__tags">
          {{trustHTML this.tagsHtml}}
        </div>
      {{/if}}

      <div class="discourse-boards-card__row discourse-boards-card__meta-data">
        {{#if this.categoryId}}
          <DAsyncContent
            @asyncData={{loadCategory}}
            @context={{this.categoryId}}
          >
            <:content as |category|>
              {{#if category}}
                <div
                  class="discourse-boards-card__category discourse-boards-card__row-item"
                >
                  {{dCategoryBadge category}}
                </div>
              {{/if}}
            </:content>
          </DAsyncContent>
        {{/if}}
        {{#if this.isDetailed}}
          <div class="discourse-boards-card__row-item">
            <div class="discourse-boards-card__last-post-by">
              {{#if this.activityDate}}
                {{dFormatDate this.activityDate format="tiny" noTitle="true"}}
              {{/if}}
              {{#if this.lastPosterUsername}}
                ({{this.lastPosterUsername}})
              {{/if}}
            </div>
            {{#if this.showAssignButton}}
              <div class="discourse-boards-card__assign">
                {{#if this.isAssigned}}
                  <DMenu
                    @class="btn-flat"
                    @identifier="boards-card-assignment"
                    @triggerClass="discourse-boards-card__assign-trigger"
                  >
                    <:trigger>
                      {{#if this.assignedAvatarHtml}}
                        {{trustHTML this.assignedAvatarHtml}}
                      {{else if this.assignedGroup}}
                        {{dIcon "group"}}
                      {{/if}}
                    </:trigger>
                    <:content as |args|>
                      <DDropdownMenu as |dropdown|>
                        {{#if this.isTopicCard}}
                          {{#each this.topicAssignments as |assignment|}}
                            <dropdown.item>
                              <DButton
                                class="btn-transparent"
                                @action={{fn
                                  this.unassignTarget
                                  assignment
                                  args.close
                                }}
                                @icon="user-xmark"
                                @translatedLabel={{assignment.unassignLabel}}
                              />
                            </dropdown.item>
                          {{/each}}
                        {{else}}
                          <dropdown.item>
                            <DButton
                              class="btn-transparent"
                              @action={{fn this.unassignFromMenu args.close}}
                              @icon="user-xmark"
                              @label="boards.board.unassign"
                            />
                          </dropdown.item>
                        {{/if}}
                        <dropdown.item>
                          <DButton
                            class="btn-transparent"
                            @action={{fn this.editAssignments args.close}}
                            @icon="pencil"
                            @label="boards.board.edit_assignments"
                          />
                        </dropdown.item>
                      </DDropdownMenu>
                    </:content>
                  </DMenu>
                {{else}}
                  <DButton
                    class="btn-flat discourse-boards-card__assign-btn"
                    @action={{this.handleAssign}}
                    @icon="user-plus"
                    @title="boards.board.assign"
                  />
                {{/if}}
              </div>
            {{/if}}

          </div>
        {{/if}}

      </div>

      {{#if this.showImage}}
        <div
          class="discourse-boards-card__row discourse-boards-card__thumbnail-row"
        >
          <img
            class="discourse-boards-card__thumbnail"
            src={{this.topic.image_url}}
          />
        </div>
      {{/if}}

    </div>
  </template>
}
