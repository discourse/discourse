import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { autoScrollSpeedForPointer } from "../lib/boards-auto-scroll";
import { isRecencyColumn } from "../lib/boards-card-ordering";
import {
  columnColorVariable,
  hasColumnColor,
} from "../lib/boards-column-helpers";
import { animateCardReorder, captureCardRects } from "../lib/boards-motion";
import BoardsCard from "./boards-card";
import BoardsAddTopicAsCardModal from "./modal/boards-add-topic-as-card";
import BoardsCardDetailModal from "./modal/boards-card-detail";

const RECENCY_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

export function recencyTimestamp(card) {
  const value = Date.parse(card?.recency_at || "");
  return Number.isFinite(value) ? value : 0;
}

export function recencyDropIndicatorInsertBefore(
  cardsContainer,
  cardElements,
  draggedCardId
) {
  return (
    cardElements.find((cardEl) => {
      const elCardId = parseInt(cardEl.dataset.cardId, 10);
      return elCardId !== draggedCardId;
    }) || cardsContainer.querySelector(".discourse-boards-column__show-all")
  );
}

export function shouldAnimateDropIndicatorPlacement({
  hadIndicator,
  columnId,
  fromColumnId,
  hasPlacedIndicator,
}) {
  return hadIndicator || columnId !== fromColumnId || hasPlacedIndicator;
}

export default class BoardsColumn extends Component {
  @service modal;

  @tracked showAllCards = false;

  autoScrollFrame = null;
  autoScrollSpeed = 0;
  autoScrollContainer = null;
  autoScrollHasDocumentListeners = false;
  stopAutoScroll = () => this.#stopAutoScroll();

  willDestroy() {
    super.willDestroy(...arguments);
    this.#stopAutoScroll();
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

  @action
  dragOver(event) {
    event.preventDefault();
    const dragData = this.args.dragData;
    if (!dragData) {
      this.#stopAutoScroll();
      return;
    }

    event.currentTarget.classList.add("discourse-boards-column--drag-target");

    const cardsContainer = event.currentTarget.querySelector(
      ".discourse-boards-column__cards"
    );
    if (!cardsContainer) {
      this.#stopAutoScroll();
      return;
    }

    this.#updateAutoScroll(cardsContainer, event.clientY);

    if (this.isRecencySorted && dragData.fromColumnId === this.args.column.id) {
      this.removeDropIndicator(event.currentTarget, { animate: true });
      return;
    }

    let indicator = cardsContainer.querySelector(
      ".discourse-boards-column__drop-indicator"
    );
    const hadIndicator = !!indicator;
    if (!indicator) {
      indicator = document.createElement("div");
      indicator.className = "discourse-boards-column__drop-indicator";
    }
    indicator.style.height = `${dragData.cardHeight}px`;

    const cardElements = [
      ...cardsContainer.querySelectorAll(".discourse-boards-card"),
    ];
    let insertBefore = null;

    if (this.isRecencySorted) {
      insertBefore = recencyDropIndicatorInsertBefore(
        cardsContainer,
        cardElements,
        dragData.cardId
      );
    } else {
      for (const cardEl of cardElements) {
        const elCardId = parseInt(cardEl.dataset.cardId, 10);
        if (elCardId === dragData.cardId) {
          continue;
        }
        const rect = cardEl.getBoundingClientRect();
        if (event.clientY <= rect.top + rect.height / 2) {
          insertBefore = cardEl;
          break;
        }
      }
    }

    const emptyMsg = cardsContainer.querySelector(
      ".discourse-boards-column__empty"
    );
    if (emptyMsg) {
      emptyMsg.hidden = true;
    }

    if (
      this.#indicatorMatchesPosition(cardsContainer, indicator, insertBefore)
    ) {
      return;
    }

    const shouldAnimate = shouldAnimateDropIndicatorPlacement({
      hadIndicator,
      columnId: this.args.column.id,
      fromColumnId: dragData.fromColumnId,
      hasPlacedIndicator: dragData.hasPlacedIndicator,
    });

    const previousRects = shouldAnimate
      ? captureCardRects(cardsContainer, {
          skipCardIds: [dragData.cardId],
        })
      : null;

    indicator.classList.remove(
      "discourse-boards-column__drop-indicator--source"
    );

    if (insertBefore) {
      cardsContainer.insertBefore(indicator, insertBefore);
    } else {
      cardsContainer.appendChild(indicator);
    }

    if (shouldAnimate) {
      animateCardReorder(cardsContainer, previousRects, {
        skipCardIds: [dragData.cardId],
      });
    }

    dragData.hasPlacedIndicator = true;
  }

  @action
  dragLeave(event) {
    event.preventDefault();
    if (!event.currentTarget.contains(event.relatedTarget)) {
      event.currentTarget.classList.remove(
        "discourse-boards-column--drag-target"
      );
      this.removeDropIndicator(event.currentTarget, { animate: true });
      this.#stopAutoScroll();
    }
  }

  @action
  drop(event) {
    event.preventDefault();
    event.currentTarget.classList.remove(
      "discourse-boards-column--drag-target"
    );
    this.#stopAutoScroll();

    const dragData = this.args.dragData;
    if (!dragData) {
      this.removeDropIndicator(event.currentTarget, { animate: false });
      return;
    }

    if (this.isRecencySorted && dragData.fromColumnId === this.args.column.id) {
      this.removeDropIndicator(event.currentTarget, { animate: false });
      return;
    }

    const cardsContainer = event.currentTarget.querySelector(
      ".discourse-boards-column__cards"
    );
    let afterCardId = null;

    if (cardsContainer && !this.isRecencySorted) {
      const cardElements = [
        ...cardsContainer.querySelectorAll(".discourse-boards-card"),
      ];
      for (const cardEl of cardElements) {
        const elCardId = parseInt(cardEl.dataset.cardId, 10);
        if (elCardId === dragData.cardId) {
          continue;
        }
        const rect = cardEl.getBoundingClientRect();
        if (event.clientY > rect.top + rect.height / 2) {
          afterCardId = elCardId;
        }
      }
    }

    this.removeDropIndicator(event.currentTarget, { animate: false });

    this.args.onDrop(
      dragData.cardId,
      this.args.column.id,
      afterCardId,
      dragData.fromColumnId
    );
  }

  removeDropIndicator(columnEl, { animate = false } = {}) {
    const cardsContainer = columnEl.querySelector(
      ".discourse-boards-column__cards"
    );
    const indicator = columnEl.querySelector(
      ".discourse-boards-column__drop-indicator"
    );
    const dragData = this.args.dragData;

    if (!indicator) {
      columnEl
        .querySelector(".discourse-boards-column__empty")
        ?.removeAttribute("hidden");
      return;
    }

    const previousRects =
      animate && cardsContainer
        ? captureCardRects(cardsContainer, {
            skipCardIds: dragData ? [dragData.cardId] : [],
          })
        : null;

    indicator.remove();

    const emptyMsg = columnEl.querySelector(".discourse-boards-column__empty");
    if (emptyMsg) {
      emptyMsg.hidden = false;
    }

    if (cardsContainer && previousRects) {
      animateCardReorder(cardsContainer, previousRects, {
        skipCardIds: dragData ? [dragData.cardId] : [],
      });
    }
  }

  #updateAutoScroll(cardsContainer, clientY) {
    const speed = autoScrollSpeedForPointer(
      clientY,
      cardsContainer.getBoundingClientRect()
    );

    if (
      (speed < 0 && cardsContainer.scrollTop <= 0) ||
      (speed > 0 &&
        cardsContainer.scrollTop + cardsContainer.clientHeight >=
          cardsContainer.scrollHeight)
    ) {
      this.#stopAutoScroll();
      return;
    }

    this.autoScrollSpeed = speed;
    this.autoScrollContainer = cardsContainer;
    this.#ensureAutoScrollDocumentListeners();

    if (speed === 0) {
      this.#stopAutoScroll();
      return;
    }

    if (!this.autoScrollFrame) {
      this.#autoScroll();
    }
  }

  #autoScroll() {
    this.autoScrollFrame = requestAnimationFrame(() => {
      this.autoScrollFrame = null;

      const container = this.autoScrollContainer;
      if (!container || this.autoScrollSpeed === 0) {
        return;
      }

      const previousScrollTop = container.scrollTop;
      container.scrollTop += this.autoScrollSpeed;

      if (container.scrollTop === previousScrollTop) {
        this.#stopAutoScroll();
        return;
      }

      this.#autoScroll();
    });
  }

  #ensureAutoScrollDocumentListeners() {
    if (this.autoScrollHasDocumentListeners) {
      return;
    }

    document.addEventListener("dragend", this.stopAutoScroll, true);
    document.addEventListener("drop", this.stopAutoScroll, true);
    this.autoScrollHasDocumentListeners = true;
  }

  #removeAutoScrollDocumentListeners() {
    if (!this.autoScrollHasDocumentListeners) {
      return;
    }

    document.removeEventListener("dragend", this.stopAutoScroll, true);
    document.removeEventListener("drop", this.stopAutoScroll, true);
    this.autoScrollHasDocumentListeners = false;
  }

  #stopAutoScroll() {
    if (this.autoScrollFrame) {
      cancelAnimationFrame(this.autoScrollFrame);
      this.autoScrollFrame = null;
    }

    this.autoScrollSpeed = 0;
    this.autoScrollContainer = null;
    this.#removeAutoScrollDocumentListeners();
  }

  #indicatorMatchesPosition(cardsContainer, indicator, insertBefore) {
    if (indicator.parentElement !== cardsContainer) {
      return false;
    }

    if (insertBefore) {
      return indicator.nextElementSibling === insertBefore;
    }

    return indicator === cardsContainer.lastElementChild;
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
      {{on "dragover" this.dragOver}}
      {{on "dragleave" this.dragLeave}}
      {{on "drop" this.drop}}
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

      <div class="discourse-boards-column__cards">
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
              @onUpdateCard={{@onUpdateCard}}
              @onDeleteCard={{@onDeleteCard}}
              @onPromoteToTopic={{fn @onPromoteToTopic card.id}}
              @onRefreshBoard={{@onRefreshBoard}}
              @columnTags={{this.columnTags}}
            />
          {{/each}}
        {{else if (eq this.cardCount 0)}}
          <div class="discourse-boards-column__empty">
            {{i18n "boards.board.no_cards"}}
          </div>
        {{/if}}

        {{#if this.hiddenCardCount}}
          <button
            type="button"
            class="discourse-boards-column__show-all"
            {{on "click" this.showAllOlderCards}}
          >
            {{i18n "boards.board.show_older_cards" count=this.hiddenCardCount}}
          </button>
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
