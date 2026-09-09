import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
import { isRecencyColumn } from "../lib/boards-card-ordering";
import {
  columnColorVariable,
  hasColumnColor,
} from "../lib/boards-column-helpers";
import {
  animateCardReorder,
  boardsMotionEnabled,
  captureCardRects,
} from "../lib/boards-motion";
import BoardsCard from "./boards-card";
import BoardsAddTopicAsCardModal from "./modal/boards-add-topic-as-card";
import BoardsCardDetailModal from "./modal/boards-card-detail";

const RECENCY_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

export function recencyTimestamp(card) {
  const value = Date.parse(card?.recency_at || "");
  return Number.isFinite(value) ? value : 0;
}

export default class BoardsColumn extends Component {
  @service modal;

  @tracked showAllCards = false;

  /** True while a compatible drag is over this column, which hides the empty message. */
  @tracked dragOver = false;

  /** The scrollable cards element, held by a modifier rather than queried. */
  @tracked cardsElement = null;

  @action
  registerCardsElement(element) {
    this.cardsElement = element;
  }

  get cardsContainer() {
    return this.cardsElement;
  }

  get cardCount() {
    return this.args.column.cards?.length || 0;
  }

  get visibleCards() {
    const cards = this.args.column.cards || [];
    if (!this.isRecencySorted || this.showAllCards) {
      return cards;
    }

    const cutoff = Date.now() - RECENCY_WINDOW_MS;
    return cards.filter(
      (card) =>
        card.id === this.args.linkedCardId || recencyTimestamp(card) >= cutoff
    );
  }

  get hiddenCardCount() {
    if (!this.isRecencySorted || this.showAllCards) {
      return 0;
    }

    return this.cardCount - this.visibleCards.length;
  }

  get isRecencySorted() {
    return isRecencyColumn(this.args.column);
  }

  get columnTags() {
    const allColumns = this.args.allColumns || [];
    return allColumns.map((col) => col.tag_name).filter(Boolean);
  }

  get columnIndex() {
    const allColumns = this.args.allColumns || [];
    return allColumns.findIndex((col) => col.id === this.args.column.id);
  }

  get lastColumnIndex() {
    return (this.args.allColumns?.length || 0) - 1;
  }

  @action
  showAllOlderCards() {
    this.showAllCards = true;
  }

  @action
  async startAddCard(closeMenu) {
    await closeMenu();
    this.modal.show(BoardsCardDetailModal, {
      model: {
        card: {},
        isNew: true,
        canWrite: true,
        onCreateCard: (data) =>
          this.args.onAddCard({ ...data, columnId: this.args.column.id }),
      },
    });
  }

  @action
  async addTopicAsCard(closeMenu) {
    await closeMenu();
    this.modal.show(BoardsAddTopicAsCardModal, {
      model: {
        onAddTopicAsCard: (data) =>
          this.args.onAddCard({ ...data, columnId: this.args.column.id }),
      },
    });
  }

  @action
  editColumn(closeMenu) {
    closeMenu();
    this.args.onEditColumn(this.args.column.id);
  }

  @action
  moveLeft(closeMenu) {
    closeMenu();
    this.args.onMoveColumn(this.args.column.id, -1);
  }

  @action
  moveRight(closeMenu) {
    closeMenu();
    this.args.onMoveColumn(this.args.column.id, 1);
  }

  @action
  clearColumn(closeMenu) {
    closeMenu();
    this.args.onClearColumn(this.args.column.id);
  }

  @action
  deleteColumn(closeMenu) {
    closeMenu();
    this.args.onDeleteColumn(this.args.column);
  }

  /**
   * Whether this column accepts the in-flight card at all. A recency column
   * orders itself, so reordering within it is meaningless and is refused
   * outright rather than accepted and ignored.
   *
   * @param {object} feedback - The target's gate feedback.
   * @returns {boolean} Whether the drop may land here.
   */
  @action
  canDropCard({ source }) {
    return !(
      this.isRecencySorted && source.data?.fromColumnId === this.args.column.id
    );
  }

  /**
   * Translates the target's position, which is relative to the single card the
   * pointer is over, into the `afterCardId` the board API expects: the id of
   * the card the dropped one should follow, or null to insert at the head.
   *
   * @param {number} overCardId - The card the pointer resolved against.
   * @param {object} event - The target's drop event.
   */
  @action
  onDropOnCard(_overCardId, event) {
    this.#dispatchDrop(event);
  }

  /**
   * Drop that landed in the column but over no card: an empty column, the
   * space past the last one, or a gap between two.
   */
  @action
  onDropOnColumn(event) {
    this.#dispatchDrop(event);
  }

  /**
   * Resolves the drop from the pointer rather than from the target's own
   * position, so which element happened to be under the cursor cannot change
   * the outcome. `afterCardId` is the last card whose midpoint the pointer is
   * strictly past, skipping the dragged card so it is never its own neighbour.
   */
  #dispatchDrop({ source, location }) {
    this.dragOver = false;

    const data = source.data;
    const draggedId = data.cardId;

    // A recency column places by recency, so the pointer carries no ordering
    // information; only the column membership changes.
    const after = this.isRecencySorted
      ? null
      : this.#afterCardForPointer(location.current.input.clientY, draggedId);

    this.args.onDrop(draggedId, this.args.column.id, after, data.fromColumnId);
  }

  #afterCardForPointer(clientY, draggedId) {
    const cards =
      this.cardsElement?.querySelectorAll(".discourse-boards-card") ?? [];

    let after = null;
    for (const cardElement of cards) {
      const id = parseInt(cardElement.dataset.cardId, 10);
      if (id === draggedId) {
        continue;
      }

      const rect = cardElement.getBoundingClientRect();
      if (clientY > rect.top + rect.height / 2) {
        after = id;
      }
    }
    return after;
  }

  /**
   * The empty-column message would otherwise sit under the drop indicator, so
   * it is hidden while a compatible drag is over the column.
   */
  @action
  onDragEnterColumn() {
    this.dragOver = true;
  }

  /**
   * Restores the empty message and plays the reorder animation for the cards
   * that shifted. The animation is boards' own, not the primitive's, so it
   * stays driven from here.
   */
  @action
  onDragLeaveColumn({ source }) {
    this.dragOver = false;
    this.#animateSettle(source?.data?.cardId);
  }

  #animateSettle(draggedId) {
    const container = this.cardsContainer;
    if (!container || !boardsMotionEnabled()) {
      return;
    }

    const skipCardIds = draggedId == null ? [] : [draggedId];
    const previousRects = captureCardRects(container, { skipCardIds });
    animateCardReorder(container, previousRects, { skipCardIds });
  }

  <template>
    <div
      class="discourse-boards-column
        {{if
          (hasColumnColor @column.color)
          'discourse-boards-column--has-color'
        }}"
      data-column-id={{@column.id}}
      data-default-sort={{@column.default_sort}}
      style={{columnColorVariable @column.color}}
      {{! The fallback for a drop that lands in the column but over no card:
      an empty column, or the space past the last one. A card target always
      wins over this, since only the deepest accepted target is dispatched. }}
      {{dDragAndDropTarget
        accepts="boards-card"
        position="inside"
        canDrop=this.canDropCard
        onDrop=this.onDropOnColumn
        onDragEnter=this.onDragEnterColumn
        onDragLeave=this.onDragLeaveColumn
      }}
    >
      <div class="discourse-boards-column__header">
        <span class="discourse-boards-column__header-content">
          <span class="discourse-boards-column__title">
            {{#if @column.icon}}{{dIcon @column.icon}}{{/if}}
            {{@column.fancyTitle}}
          </span>
          <span class="discourse-boards-column__count">
            {{this.cardCount}}
          </span>
        </span>
        {{#if @canManage}}
          <DMenu
            @identifier="boards-column-controls"
            @icon="ellipsis"
            @title="boards.board.column_controls"
            @triggerClass="btn-flat btn-small discourse-boards-column__menu-trigger"
          >
            <:content as |args|>
              <DDropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @action={{fn this.editColumn args.close}}
                    @icon="pencil"
                    @label="boards.board.edit_column"
                    class="btn-transparent discourse-boards-column__menu-edit"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.moveLeft args.close}}
                    @icon="arrow-left"
                    @label="boards.board.move_left"
                    @disabled={{eq this.columnIndex 0}}
                    class="btn-transparent discourse-boards-column__menu-move-left"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.moveRight args.close}}
                    @icon="arrow-right"
                    @label="boards.board.move_right"
                    @disabled={{eq this.columnIndex this.lastColumnIndex}}
                    class="btn-transparent discourse-boards-column__menu-move-right"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.clearColumn args.close}}
                    @icon="xmark"
                    @label="boards.board.clear_column"
                    @disabled={{eq this.cardCount 0}}
                    class="btn-transparent discourse-boards-column__menu-clear"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.deleteColumn args.close}}
                    @icon="trash-can"
                    @label="boards.board.delete_column"
                    class="btn-transparent btn-danger discourse-boards-column__menu-delete"
                  />
                </dropdown.item>
              </DDropdownMenu>
            </:content>
          </DMenu>
        {{/if}}
      </div>

      <div
        class="discourse-boards-column__cards"
        {{dDragAndDropAutoScroll types="boards-card" axis="vertical"}}
        {{didInsert this.registerCardsElement}}
      >
        {{#if this.visibleCards.length}}
          {{#each this.visibleCards key="id" as |card|}}
            <BoardsCard
              @card={{card}}
              @board={{@board}}
              @columnTitle={{@column.fancyTitle}}
              @columnIcon={{@column.icon}}
              @columnColor={{@column.color}}
              @canWrite={{@canWrite}}
              @allSameCategory={{@allSameCategory}}
              @isDropHighlighted={{eq @dropHighlightCardId card.id}}
              @isLinkHighlighted={{eq @linkHighlightCardId card.id}}
              @onDragStart={{@onDragStart}}
              @onDragEnd={{@onDragEnd}}
              @canDropCard={{this.canDropCard}}
              @onDropOnCard={{this.onDropOnCard}}
              @onUpdateCard={{@onUpdateCard}}
              @onDeleteCard={{@onDeleteCard}}
              @onPromoteToTopic={{fn @onPromoteToTopic card.id}}
              @onRefreshBoard={{@onRefreshBoard}}
              @columnTags={{this.columnTags}}
            />
          {{/each}}
        {{else if (eq this.cardCount 0)}}
          <div class="discourse-boards-column__empty" hidden={{this.dragOver}}>
            {{i18n "boards.board.no_cards"}}
          </div>
        {{/if}}

        {{#if this.hiddenCardCount}}
          <DButton
            class="btn-flat discourse-boards-column__show-all"
            @action={{this.showAllOlderCards}}
            @translatedLabel={{i18n
              "boards.board.show_older_cards"
              count=this.hiddenCardCount
            }}
          />
        {{/if}}
      </div>

      {{#if @canWrite}}
        <div class="discourse-boards-column__footer">
          <DMenu
            @identifier="boards-column-add"
            @icon="plus"
            @label={{i18n "boards.board.add_card"}}
            @triggerClass="discourse-boards-column__add-btn"
          >
            <:content as |args|>
              <DDropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @action={{fn this.startAddCard args.close}}
                    @icon="plus"
                    @label="boards.board.add_card"
                    class="btn-transparent"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.addTopicAsCard args.close}}
                    @icon="link"
                    @label="boards.board.add_topic_as_card"
                    class="btn-transparent"
                  />
                </dropdown.item>
              </DDropdownMenu>
            </:content>
          </DMenu>
        </div>
      {{/if}}
    </div>
  </template>
}
