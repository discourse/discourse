import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import TopicStatus from "discourse/components/topic-status";
import DMenu from "discourse/float-kit/components/d-menu";
import discourseLater from "discourse/lib/later";
import renderTags from "discourse/lib/render-tags";
import { emojiUnescape } from "discourse/lib/text";
import DiscourseURL from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { renderAvatar } from "discourse/ui-kit/helpers/d-user-avatar";
import { i18n } from "discourse-i18n";
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
  dragHideTimer = null;
  dragImageElement = null;

  willDestroy() {
    super.willDestroy(...arguments);
    const isActiveDragSource =
      this.dragging || this.dragHideTimer || this.dragImageElement;

    this.#clearDragHideTimer();
    this.#cleanupDragImage();

    if (isActiveDragSource) {
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

    return tags.filter((tag) => {
      const name = typeof tag === "string" ? tag : tag.name;
      return !this.columnTagNames.has(name?.toLowerCase());
    });
  }

  get tagsHtml() {
    if (this.isTopicCard) {
      if (!this.args.board.show_tags || !this.topic?.tags) {
        return null;
      }

      const filtered = this.topic.tags.filter(
        (tag) => !this.columnTagNames.has(tag.toLowerCase())
      );

      return filtered.length ? renderTags(null, { tags: filtered }) : null;
    }

    const tags = this.visibleFloaterTags;
    return tags.length ? renderTags(null, { tags }) : null;
  }

  get category() {
    if (this.args.allSameCategory || !this.topic?.category_id) {
      return null;
    }
    return Category.findById(this.topic.category_id);
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

  get assignedUser() {
    return this.allAssignedUsers[0] ?? null;
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
    return this.args.canWrite;
  }

  get showAssignButton() {
    if (!this.isTopicCard) {
      return this.canAssign;
    }

    return this.canAssign && !this.topicStatusModel?.closed;
  }

  get canAssign() {
    return (
      this.siteSettings.assign_enabled &&
      this.currentUser?.can_assign &&
      (this.isTopicCard || this.args.canWrite)
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

  get floaterTagsHtml() {
    const tags = this.args.card.tags;
    if (this.isTopicCard || !tags?.length) {
      return null;
    }
    return renderTags(null, { tags });
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
          canWrite: this.args.canWrite,
          onUpdateCard: this.args.onUpdateCard,
        },
      })
      .finally(() => {
        if (!this.isDestroying && !this.isDestroyed) {
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
        if (!navigatedAway && !this.isDestroying && !this.isDestroyed) {
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
  dragStart(event) {
    if (!this.args.canWrite) {
      event.preventDefault();
      return;
    }

    const cardRect = event.currentTarget.getBoundingClientRect();
    this.#setDragImage(event, event.currentTarget, cardRect);

    this.args.onDragStart({
      cardId: this.args.card.id,
      topicId: this.args.card.topic_id,
      fromColumnId: this.args.card.column_id,
      cardHeight: cardRect.height,
      hasPlacedIndicator: false,
    });
    event.dataTransfer.effectAllowed = "move";
    event.stopPropagation();

    this.#scheduleDragSourceHide(event.currentTarget, cardRect.height);
  }

  @action
  dragEnd() {
    this.args.onDragEnd?.(this.args.card.id);
    this.#clearDragHideTimer();
    this.#removeDropIndicators();
    this.dragging = false;
    this.#cleanupDragImage();
  }

  #scheduleDragSourceHide(cardElement, cardHeight) {
    this.#clearDragHideTimer();

    this.dragHideTimer = discourseLater(this, () => {
      this.dragHideTimer = null;

      if (!this.isDestroying && !this.isDestroyed) {
        if (shouldInsertSourceDropIndicator()) {
          this.#insertSourceDropIndicator(cardElement, cardHeight);
        }
        this.dragging = true;
      }
    });
  }

  #clearDragHideTimer() {
    if (this.dragHideTimer) {
      cancel(this.dragHideTimer);
      this.dragHideTimer = null;
    }
  }

  #setDragImage(event, cardElement, cardRect) {
    if (!event.dataTransfer?.setDragImage) {
      return;
    }

    this.#cleanupDragImage();

    const dragImage = cardElement.cloneNode(true);
    dragImage.classList.remove("discourse-boards-card--dragging");
    dragImage.classList.add("discourse-boards-card--drag-image");
    dragImage.style.width = `${cardRect.width}px`;
    dragImage.style.height = `${cardRect.height}px`;
    dragImage.setAttribute("aria-hidden", "true");

    document.body.append(dragImage);
    this.dragImageElement = dragImage;

    // Fallback for programmatic or test drags where the pointer coordinates are 0.
    const offsetX =
      event.clientX > 0 ? Math.max(event.clientX - cardRect.left, 0) : 24;
    const offsetY =
      event.clientY > 0 ? Math.max(event.clientY - cardRect.top, 0) : 24;

    event.dataTransfer.setDragImage(dragImage, offsetX, offsetY);
  }

  #cleanupDragImage() {
    this.dragImageElement?.remove();
    this.dragImageElement = null;
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
        (if this.dragging "discourse-boards-card--dragging")
        (unless this.isTopicCard "discourse-boards-card--floater")
        (if @isDropHighlighted "discourse-boards-card--drop-highlighted")
        (if @isLinkHighlighted "discourse-boards-card--link-highlighted")
      }}
      draggable={{if @canWrite "true" "false"}}
      role="button"
      tabindex="0"
      data-card-id={{@card.id}}
      data-topic-id={{@card.topic_id}}
      {{on "dragstart" this.dragStart}}
      {{on "dragend" this.dragEnd}}
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
                href={{this.inlineOneboxData.url}}
                class={{dConcatClass
                  "inline-onebox"
                  this.inlineOneboxData.css_class
                }}
                target="_blank"
                rel="noopener noreferrer"
              >{{this.inlineOneboxData.title}}</a>
            {{else}}
              <AutoLinkedText @text={{this.cardTitle}} />
            {{/if}}
          </span>
        {{/if}}
        {{#if this.canShowActions}}
          <DMenu
            @identifier="boards-card-actions"
            @icon="ellipsis"
            @triggerClass="btn-flat btn-small discourse-boards-card__actions-trigger"
          >
            <:content>
              <DDropdownMenu as |dropdown|>
                {{#unless this.isTopicCard}}
                  <dropdown.item>
                    <DButton
                      @action={{this.openDetailModal}}
                      @icon="pencil"
                      @label="edit"
                      class="btn-transparent"
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      @action={{@onPromoteToTopic}}
                      @icon="plus"
                      @label="boards.board.new_topic"
                      class="btn-transparent"
                    />
                  </dropdown.item>
                {{/unless}}
                <dropdown.item>
                  <DButton
                    @action={{this.removeCard}}
                    @icon="trash-can"
                    @label="boards.board.remove_card"
                    class="btn-transparent btn-danger"
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
        {{#if this.category}}
          <div
            class="discourse-boards-card__category discourse-boards-card__row-item"
          >
            {{dCategoryBadge this.category}}
          </div>
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
                    @identifier="boards-card-assignment"
                    @triggerClass="discourse-boards-card__assign-trigger"
                    @class="btn-flat"
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
                                @action={{fn
                                  this.unassignTarget
                                  assignment
                                  args.close
                                }}
                                @translatedLabel={{assignment.unassignLabel}}
                                @icon="user-xmark"
                                class="btn-transparent"
                              />
                            </dropdown.item>
                          {{/each}}
                        {{else}}
                          <dropdown.item>
                            <DButton
                              @action={{fn this.unassignFromMenu args.close}}
                              @icon="user-xmark"
                              @label="boards.board.unassign"
                              class="btn-transparent"
                            />
                          </dropdown.item>
                        {{/if}}
                        <dropdown.item>
                          <DButton
                            @action={{fn this.editAssignments args.close}}
                            @icon="pencil"
                            @label="boards.board.edit_assignments"
                            class="btn-transparent"
                          />
                        </dropdown.item>
                      </DDropdownMenu>
                    </:content>
                  </DMenu>
                {{else}}
                  <DButton
                    @action={{this.handleAssign}}
                    @icon="user-plus"
                    @title="boards.board.assign"
                    class="btn-flat discourse-boards-card__assign-btn"
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
