import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import BackButton from "discourse/components/back-button";
import PermanentlyDeleteConfirmModal from "discourse/components/modal/permanently-delete-confirm";
import DMenu from "discourse/float-kit/components/d-menu";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import bodyClass from "discourse/helpers/body-class";
import { reload } from "discourse/helpers/page-reloader";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { waitForAnimationEnd } from "discourse/lib/animation-utils";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import DiscourseURL from "discourse/lib/url";
import { prefersReducedMotion } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dBoundCategoryLink from "discourse/ui-kit/helpers/d-bound-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  autoScrollSpeedForPointer,
  dragToScroll,
} from "../lib/boards-auto-scroll";
import {
  isRecencyColumn,
  sortCardsForColumn,
} from "../lib/boards-card-ordering";
import { boardsBoardConfigureUrl, boardsBoardUrl } from "../lib/boards-urls";
import Board from "../models/board";
import Card from "../models/card";
import Column from "../models/column";
import BoardsColumn from "./boards-column";
import BoardsBoardSettings from "./modal/boards-board-settings";
import BoardsCardDetailModal from "./modal/boards-card-detail";
import BoardsColumnSettings from "./modal/boards-column-settings";
import BoardsConstraintFix from "./modal/boards-constraint-fix";
import BoardsTopicCardDetailModal from "./modal/boards-topic-card-detail";

const onWindowResize = modifier((element, [callback]) => {
  const wrappedCallback = () => callback(element);
  window.addEventListener("resize", wrappedCallback);

  const visualViewport = window.visualViewport;
  if (visualViewport) {
    visualViewport.addEventListener("resize", wrappedCallback);
  }

  return () => {
    window.removeEventListener("resize", wrappedCallback);
    if (visualViewport) {
      visualViewport.removeEventListener("resize", wrappedCallback);
    }
  };
});

const matchLastColumnHeight = modifier((element) => {
  const container = element.parentElement;
  if (!container) {
    return;
  }

  const update = () => {
    const columns = container.querySelectorAll(
      ":scope > .discourse-boards-column"
    );
    const last = columns[columns.length - 1];
    element.style.height = last ? `${last.offsetHeight}px` : "";
    columns.forEach((col) => ro.observe(col));
  };

  const ro = new ResizeObserver(update);
  ro.observe(container);
  update();

  return () => ro.disconnect();
});

function calcAvailableHeight(element) {
  schedule("afterRender", () => {
    const vv = window.visualViewport;
    const viewportHeight = vv?.height ?? window.innerHeight;
    const offsetTop = vv?.offsetTop ?? 0;
    const top = element.getBoundingClientRect().top - offsetTop;
    const available = viewportHeight - top;
    document.documentElement.style.setProperty(
      "--discourse-boards-available-height",
      `${available}px`
    );
  });
}

export function shouldRefetchMovedCardPayload(existingCard, cardPayload) {
  return !existingCard && !!cardPayload?.topic_id && !cardPayload.topic;
}

export default class BoardsBoardViewer extends Component {
  @service appEvents;
  @service composer;
  @service dialog;
  @service messageBus;
  @service modal;
  @service router;
  @service toasts;

  @tracked board;
  @tracked columns;
  @tracked dragData = null;
  @tracked dropHighlightCardId = null;
  @tracked fullscreen = false;
  @tracked linkHighlightCardId = null;
  @tracked linkedCardId = null;

  horizontalAutoScrollFrame = null;
  horizontalAutoScrollSpeed = 0;
  horizontalAutoScrollContainer = null;
  horizontalAutoScrollHasDocumentListeners = false;
  stopHorizontalAutoScroll = () => this.#stopHorizontalAutoScroll();
  updateHorizontalAutoScroll = (event) => {
    if (!this.dragData || !this.horizontalAutoScrollContainer) {
      this.#stopHorizontalAutoScroll();
      return;
    }

    this.#updateHorizontalAutoScroll(
      this.horizontalAutoScrollContainer,
      event.clientX
    );
  };

  setupMessageBus = modifier((element) => {
    const channel = `/boards/${this.board.id}`;
    this.messageBus.subscribe(channel, this.onBoardMessage);

    const handleKeyboardMove = (event) => {
      this.#handleCardMoved(event.detail);
    };
    element.addEventListener("boards:card-moved", handleKeyboardMove);

    return () => {
      this.messageBus.unsubscribe(channel, this.onBoardMessage);
      element.removeEventListener("boards:card-moved", handleKeyboardMove);
    };
  });

  _promotionAppEventListenersBound = false;
  _promotionRouteListenerBound = false;

  constructor() {
    super(...arguments);
    this.board = Board.create(this.args.model.board);
    this.columns = this.args.model.columns.map((column) =>
      Column.create(column)
    );

    if (this.args.initialCardId) {
      schedule("afterRender", () => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        const card = this.#findCard(this.args.initialCardId);
        if (card) {
          this.#openInitialCardModal(card);
        } else {
          DiscourseURL.routeTo(boardsBoardUrl(this.board));
        }
      });
    }

    if (this.args.highlightCardId) {
      schedule("afterRender", () => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        this.#focusHighlightCard(this.args.highlightCardId);
      });
    }

    if (this.args.openBoardSettings && this.canManage) {
      schedule("afterRender", () => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        this.#openBoardSettingsModal({ updateUrl: false });
      });
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this._clearDropHighlight();
    this._cleanupPromotion();
    this.#stopHorizontalAutoScroll();
  }

  @bind
  onBoardMessage(data) {
    if (data.client_id && data.client_id === this.messageBus.clientId) {
      return;
    }

    switch (data.type) {
      case "card_created":
        this.#handleCardCreated(data.card);
        break;
      case "card_updated":
        this.#handleCardUpdated(data.card);
        break;
      case "card_moved":
        this.#handleCardMoved(data.card);
        break;
      case "card_deleted":
        this.#handleCardDeleted(data.card_id);
        break;
      case "column_cleared":
        this.#handleColumnCleared(data.column_id);
        break;
      case "columns_reordered":
        this.#handleColumnsReordered(data.column_order);
        break;
      case "board_updated":
        this.#handleBoardUpdated();
        break;
    }
  }

  #handleCardCreated(card) {
    if (card.topic_id && !card.topic) {
      this.#handleBoardUpdated();
      return;
    }

    card = Card.create(card);
    this.columns = this.columns.map((col) => {
      if (col.id === card.column_id) {
        return col.copy({
          cards: sortCardsForColumn(col, [
            ...col.cards.filter((c) => c.id !== card.id),
            card,
          ]),
        });
      }
      return col;
    });
  }

  #handleCardUpdated(card) {
    this.columns = this.columns.map((col) => {
      const cards = col.cards.map((c) => (c.id === card.id ? c.copy(card) : c));
      return col.copy({ cards: sortCardsForColumn(col, cards) });
    });
  }

  #handleCardMoved(card) {
    const existing = this.#findCard(card.id);
    if (shouldRefetchMovedCardPayload(existing, card)) {
      this.#handleBoardUpdated();
      return;
    }

    const mergedCard = existing ? existing.copy(card) : Card.create(card);

    const withoutCard = this.columns.map((col) =>
      col.copy({
        cards: col.cards.filter((c) => c.id !== card.id),
      })
    );

    this.columns = withoutCard.map((col) => {
      if (col.id === mergedCard.column_id) {
        return col.copy({
          cards: sortCardsForColumn(col, [...col.cards, mergedCard]),
        });
      }
      return col;
    });
  }

  #handleCardDeleted(cardId) {
    this.columns = this.columns.map((col) =>
      col.copy({
        cards: col.cards.filter((c) => c.id !== cardId),
      })
    );
  }

  #handleColumnCleared(columnId) {
    this.columns = this.columns.map((col) => {
      if (col.id === columnId) {
        return col.copy({ cards: [] });
      }
      return col;
    });
  }

  #handleColumnsReordered(columnOrder) {
    const orderMap = new Map(columnOrder.map((id, idx) => [id, idx]));
    this.columns = [...this.columns].sort(
      (a, b) =>
        (orderMap.get(a.id) ?? Infinity) - (orderMap.get(b.id) ?? Infinity)
    );
  }

  async #handleBoardUpdated() {
    try {
      const result = await ajax(`/boards/api/boards/${this.board.id}.json`);
      if (result.columns) {
        this.columns = result.columns.map((col) =>
          Column.create({
            ...col,
            cards: sortCardsForColumn(col, col.cards || []),
          })
        );
      }
      Object.assign(this.board, result.board || result);
    } catch {
      // Board may have been deleted — no action needed
    }
  }

  @bind
  refreshBoard() {
    return this.#handleBoardUpdated();
  }

  get canWrite() {
    return this.board.can_write;
  }

  get canManage() {
    return this.board.can_manage;
  }

  get boardCategories() {
    return (this.board.category_ids || [])
      .map((id) => Category.findById(id))
      .filter(Boolean);
  }

  get boardTagNames() {
    return this.board.tag_names || [];
  }

  get hasBoardFilters() {
    return this.boardCategories.length > 0 || this.boardTagNames.length > 0;
  }

  get allSameCategory() {
    let seenCategory = null;
    for (const col of this.columns) {
      for (const card of col.cards || []) {
        const catId = card.topic?.category_id;
        if (catId == null) {
          continue;
        }
        if (seenCategory === null) {
          seenCategory = catId;
        } else if (seenCategory !== catId) {
          return false;
        }
      }
    }
    return true;
  }

  @action
  toggleFullscreen() {
    this.fullscreen = !this.fullscreen;
  }

  @action
  exitFullscreen() {
    this.fullscreen = false;
  }

  @action
  onDragStart(data) {
    this.dragData = data;
  }

  @action
  onDragEnd(cardId) {
    next(this, () => {
      if (this.dragData?.cardId === cardId) {
        this.dragData = null;
      }
    });
  }

  @action
  dragOverBoardContainer(event) {
    const dragData = this.dragData;
    if (!dragData) {
      this.#stopHorizontalAutoScroll();
      return;
    }

    event.preventDefault();
    this.#updateHorizontalAutoScroll(event.currentTarget, event.clientX);
  }

  @action
  dragLeaveBoardContainer(event) {
    if (!this.dragData && !event.currentTarget.contains(event.relatedTarget)) {
      this.#stopHorizontalAutoScroll();
    }
  }

  @action
  dropBoardContainer() {
    this.#stopHorizontalAutoScroll();
  }

  @action
  async onDrop(cardId, toColumnId, afterCardId, fromColumnId) {
    if (!fromColumnId) {
      return;
    }

    const fromColumn = this.columns.find((c) => c.id === fromColumnId);
    const toColumn = this.columns.find((c) => c.id === toColumnId);
    if (!fromColumn || !toColumn) {
      return;
    }

    const cardIndex = fromColumn.cards.findIndex((c) => c.id === cardId);
    if (cardIndex === -1) {
      return;
    }

    const card = fromColumn.cards[cardIndex];
    const isSameColumn = fromColumnId === toColumnId;
    const targetIsRecency = isRecencyColumn(toColumn);
    if (isSameColumn && targetIsRecency) {
      this.dragData = null;
      return;
    }

    if (targetIsRecency) {
      afterCardId = null;
    }

    let constraintFix = null;

    if (!isSameColumn && card.topic) {
      try {
        constraintFix = await this.#resolveConstraintFix(
          card.topic_id || card.topic.id,
          card.topic,
          toColumn
        );
      } catch (error) {
        popupAjaxError(error);
        return;
      }

      if (constraintFix === false) {
        return;
      }
    }

    if (!isSameColumn && !constraintFix && this.board.require_confirmation) {
      const confirmed = await this._confirmMove(card, toColumn);
      if (!confirmed) {
        return;
      }
    }

    const snapshot = this.columns.map((col) =>
      col.copy({ cards: col.cards.map((c) => c.copy()) })
    );

    fromColumn.cards.splice(cardIndex, 1);

    let insertIndex = targetIsRecency ? 0 : toColumn.cards.length;
    if (!targetIsRecency && afterCardId != null) {
      const idx = toColumn.cards.findIndex((c) => c.id === afterCardId);
      if (idx !== -1) {
        insertIndex = idx + 1;
      }
    } else {
      insertIndex = 0;
    }
    toColumn.cards.splice(insertIndex, 0, card);
    card.column_id = toColumnId;

    this.columns = this.columns.map((col) => {
      if (col.id === fromColumnId || col.id === toColumnId) {
        return col.copy({ cards: [...col.cards] });
      }
      return col;
    });
    this.dragData = null;

    const data = {
      client_id: this.messageBus.clientId,
      card: {
        column_id: toColumnId,
        after_card_id: afterCardId,
      },
    };
    if (constraintFix) {
      data.constraint_fix = constraintFix;
    }

    try {
      const result = await ajax(
        `/boards/api/boards/${this.board.id}/cards/${card.id}`,
        { type: "PUT", data }
      );
      if (result?.card) {
        const existingCard = this.columns
          .flatMap((col) => col.cards)
          .find((c) => c.id === result.card.id);
        const mergedCard = existingCard
          ? existingCard.copy(result.card)
          : Card.create(result.card);
        const withoutCard = this.columns.map((col) =>
          col.copy({
            cards: col.cards.filter((c) => c.id !== result.card.id),
          })
        );

        this.columns = withoutCard.map((col) => {
          if (col.id === mergedCard.column_id) {
            return col.copy({
              cards: sortCardsForColumn(col, [...col.cards, mergedCard]),
            });
          }
          return col;
        });
      }
      this._highlightDroppedCard(card.id);
    } catch (error) {
      this.columns = snapshot;
      popupAjaxError(error);
    }
  }

  #updateHorizontalAutoScroll(container, clientX) {
    const speed = autoScrollSpeedForPointer(
      clientX,
      container.getBoundingClientRect(),
      "x"
    );

    if (
      (speed < 0 && container.scrollLeft <= 0) ||
      (speed > 0 &&
        container.scrollLeft + container.clientWidth >= container.scrollWidth)
    ) {
      this.#stopHorizontalAutoScroll();
      return;
    }

    this.horizontalAutoScrollSpeed = speed;
    this.horizontalAutoScrollContainer = container;
    this.#ensureHorizontalAutoScrollDocumentListeners();

    if (speed === 0) {
      this.#stopHorizontalAutoScroll();
      return;
    }

    if (!this.horizontalAutoScrollFrame) {
      this.#horizontalAutoScroll();
    }
  }

  #horizontalAutoScroll() {
    this.horizontalAutoScrollFrame = requestAnimationFrame(() => {
      this.horizontalAutoScrollFrame = null;

      const container = this.horizontalAutoScrollContainer;
      if (!container || this.horizontalAutoScrollSpeed === 0) {
        return;
      }

      const previousScrollLeft = container.scrollLeft;
      container.scrollLeft += this.horizontalAutoScrollSpeed;

      if (container.scrollLeft === previousScrollLeft) {
        this.#stopHorizontalAutoScroll();
        return;
      }

      this.#horizontalAutoScroll();
    });
  }

  #ensureHorizontalAutoScrollDocumentListeners() {
    if (this.horizontalAutoScrollHasDocumentListeners) {
      return;
    }

    document.addEventListener(
      "dragover",
      this.updateHorizontalAutoScroll,
      true
    );
    document.addEventListener("dragend", this.stopHorizontalAutoScroll, true);
    document.addEventListener("drop", this.stopHorizontalAutoScroll, true);
    this.horizontalAutoScrollHasDocumentListeners = true;
  }

  #removeHorizontalAutoScrollDocumentListeners() {
    if (!this.horizontalAutoScrollHasDocumentListeners) {
      return;
    }

    document.removeEventListener(
      "dragover",
      this.updateHorizontalAutoScroll,
      true
    );
    document.removeEventListener(
      "dragend",
      this.stopHorizontalAutoScroll,
      true
    );
    document.removeEventListener("drop", this.stopHorizontalAutoScroll, true);
    this.horizontalAutoScrollHasDocumentListeners = false;
  }

  #stopHorizontalAutoScroll() {
    if (this.horizontalAutoScrollFrame) {
      cancelAnimationFrame(this.horizontalAutoScrollFrame);
      this.horizontalAutoScrollFrame = null;
    }

    this.horizontalAutoScrollSpeed = 0;
    this.horizontalAutoScrollContainer = null;
    this.#removeHorizontalAutoScrollDocumentListeners();
  }

  _showConstraintFixModal(topic, column, mismatches) {
    return new Promise((resolve) => {
      this.modal.show(BoardsConstraintFix, {
        model: {
          topic,
          board: this.board,
          column,
          mismatches,
          onConfirm: (result) => resolve(result),
          onCancel: () => resolve(null),
        },
      });
    });
  }

  _confirmMove(card, toColumn) {
    return new Promise((resolve) => {
      const cardTitle = card.fancyTitle || "";
      this.dialog.yesNoConfirm({
        message: i18n("boards.board.move_confirm", {
          topic_title: cardTitle,
          column_title: toColumn.fancyTitle,
        }),
        didConfirm: () => resolve(true),
        didCancel: () => resolve(false),
      });
    });
  }

  @action
  async onDeleteCard(cardId) {
    const snapshot = this.columns.map((col) =>
      col.copy({ cards: [...col.cards] })
    );

    this.columns = this.columns.map((col) =>
      col.copy({
        cards: col.cards.filter((c) => c.id !== cardId),
      })
    );

    try {
      await ajax(`/boards/api/boards/${this.board.id}/cards/${cardId}`, {
        type: "DELETE",
        data: { client_id: this.messageBus.clientId },
      });
    } catch (error) {
      this.columns = snapshot;
      popupAjaxError(error);
    }
  }

  @action
  async onUpdateCard(cardId, updates) {
    try {
      const result = await ajax(
        `/boards/api/boards/${this.board.id}/cards/${cardId}`,
        {
          type: "PUT",
          data: { client_id: this.messageBus.clientId, card: updates },
        }
      );

      if (result.card) {
        if (result.adopted_floater_id) {
          this.columns = this.columns.map((col) =>
            col.copy({
              cards: col.cards.filter((c) => c.id !== cardId),
            })
          );
          this.#handleCardMoved(result.card);
        } else {
          this.#handleCardUpdated(result.card);
        }
      }
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  @action
  async onAddCard({
    topicId,
    title,
    columnId,
    notes,
    tag_ids,
    assigned_to_name,
  }) {
    if (topicId) {
      try {
        const column = this.columns.find(
          (candidate) => candidate.id === columnId
        );
        const constraintFix = await this.#resolveConstraintFix(
          topicId,
          { id: topicId },
          column
        );
        if (constraintFix === false) {
          return;
        }

        const data = {
          client_id: this.messageBus.clientId,
          card: { column_id: columnId, topic_id: topicId },
        };
        if (constraintFix) {
          data.constraint_fix = constraintFix;
        }

        const result = await ajax(`/boards/api/boards/${this.board.id}/cards`, {
          type: "POST",
          data,
        });
        this.#appendCardToColumn(result.card, columnId);
        return;
      } catch (error) {
        if (this.#isTopicNotFoundError(error)) {
          await this.#createFallbackFloater(title, columnId);
          return;
        }
        popupAjaxError(error);
        return;
      }
    }

    try {
      const result = await ajax(`/boards/api/boards/${this.board.id}/cards`, {
        type: "POST",
        data: {
          client_id: this.messageBus.clientId,
          card: {
            column_id: columnId,
            title,
            notes,
            tag_ids,
            assigned_to_name,
          },
        },
      });
      this.#appendCardToColumn(result.card, columnId);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #resolveConstraintFix(topicId, topic, column) {
    if (!column) {
      return null;
    }

    const response = await ajax(
      `/boards/api/boards/${this.board.id}/check-constraint-mismatches`,
      {
        method: "PUT",
        data: {
          topic_id: topicId,
          target_column_id: column.id,
        },
      }
    );

    if (!response.constraints_need_fixing) {
      return null;
    }

    const mismatches = {
      needsTags: response.tags_needed.length > 0,
      needsCategory: response.categories_needed.length > 0,
      boardTagNames: response.tags_needed,
      boardCategoryIds: response.categories_needed,
    };

    const constraintFix = await this._showConstraintFixModal(
      topic,
      column,
      mismatches
    );

    return constraintFix ?? false;
  }

  #isTopicNotFoundError(error) {
    return error?.jqXHR?.status === 404;
  }

  #appendCardToColumn(card, columnId) {
    if (!card) {
      return;
    }
    card = Card.create(card);
    this.columns = this.columns.map((col) => {
      if (col.id === columnId) {
        return col.copy({
          cards: sortCardsForColumn(col, [
            ...col.cards.filter((c) => c.id !== card.id),
            card,
          ]),
        });
      }
      return col;
    });
  }

  async #createFallbackFloater(title, columnId) {
    try {
      const result = await ajax(`/boards/api/boards/${this.board.id}/cards`, {
        type: "POST",
        data: {
          client_id: this.messageBus.clientId,
          card: { column_id: columnId, title },
        },
      });
      this.#appendCardToColumn(result.card, columnId);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  onPromoteToTopic(cardId) {
    let card;
    let column;
    for (const col of this.columns) {
      const found = col.cards.find((c) => c.id === cardId);
      if (found) {
        card = found;
        column = col;
        break;
      }
    }
    if (!card) {
      return;
    }

    this._promotingCardId = cardId;
    this.#bindPromotionListeners();

    const opts = { title: card.title };
    if (card.notes) {
      opts.body = card.notes;
    }

    const tagNames = new Set();
    if (card.tags?.length) {
      card.tags.forEach((tag) => tagNames.add(tag.name));
    }
    if (this.board.tag_names?.length) {
      this.board.tag_names.forEach((name) => tagNames.add(name));
    }
    if (column.tag_name) {
      tagNames.add(column.tag_name);
    }
    if (tagNames.size) {
      opts.tags = [...tagNames].join(",");
    }

    const categoryId =
      column.move_to_category_id || this.board.category_ids?.[0];
    if (categoryId) {
      opts.category = Category.findById(categoryId);
    }
    this.composer.openNewTopic(opts);
  }

  // Column management actions

  @action
  openAddColumnModal(closeMenu) {
    if (typeof closeMenu === "function") {
      closeMenu();
    }
    this.modal.show(BoardsColumnSettings, {
      model: {
        column: null,
        board: this.board,
        onSave: (columnData) => this.addColumn(columnData),
      },
    });
  }

  @action
  openEditColumnModal(columnId) {
    const column = this.columns.find((c) => c.id === columnId);
    if (!column) {
      return;
    }
    this.modal.show(BoardsColumnSettings, {
      model: {
        column,
        board: this.board,
        onSave: (columnData) => this.editColumn(columnId, columnData),
      },
    });
  }

  _serializeColumn(col) {
    return {
      id: col.id,
      title: col.title,
      icon: col.icon,
      color: col.color || null,
      default_sort: col.default_sort || "priority",
      tag_name: col.tag_name || null,
      move_to_category_id: col.move_to_category_id,
      move_to_assigned:
        col.move_to_assigned === "_user" ? "" : col.move_to_assigned,
      move_to_status: col.move_to_status,
    };
  }

  @action
  async addColumn(columnData) {
    await this._saveColumn(
      "POST",
      `/boards/api/boards/${this.board.id}/columns`,
      {
        column: this._serializeColumn(columnData),
      }
    );
  }

  @action
  async editColumn(columnId, columnData) {
    const column = this.columns.find((col) => col.id === columnId);
    if (!column) {
      return;
    }

    await this._saveColumn(
      "PUT",
      `/boards/api/boards/${this.board.id}/columns/${columnId}`,
      { column: this._serializeColumn(column.copy(columnData)) }
    );
  }

  @action
  async moveColumn(columnId, direction) {
    const index = this.columns.findIndex((c) => c.id === columnId);
    if (index === -1) {
      return;
    }
    const newIndex = index + direction;
    if (newIndex < 0 || newIndex >= this.columns.length) {
      return;
    }

    const snapshot = this.columns;
    const reordered = [...this.columns];
    [reordered[index], reordered[newIndex]] = [
      reordered[newIndex],
      reordered[index],
    ];

    this.columns = reordered;
    try {
      const result = await ajax(
        `/boards/api/boards/${this.board.id}/move-column`,
        {
          type: "POST",
          data: {
            column_id: columnId,
            direction,
            client_id: this.messageBus.clientId,
          },
        }
      );
      if (result?.column_order) {
        this.#handleColumnsReordered(result.column_order);
      }
    } catch (error) {
      this.columns = snapshot;
      popupAjaxError(error);
    }
  }

  @action
  async deleteColumn(column) {
    const saveColumns = async () => {
      try {
        return await this._saveColumn(
          "DELETE",
          `/boards/api/boards/${this.board.id}/columns/${column.id}`
        );
      } catch (error) {
        popupAjaxError(error);
      }
    };

    // No need for confirmation if there are no cards in the column.
    if (column.cards.length === 0) {
      await saveColumns();
      return;
    }

    // Need a bit of a stronger delete confirmation when getting rid
    // of a lot of cards.
    if (column.cards.length > 5) {
      return this.modal.show(PermanentlyDeleteConfirmModal, {
        model: {
          message: i18n("boards.board.confirm_delete_column_with_cards", {
            count: column.cards.length,
          }),
          confirmPhrase: column.title,
          didConfirm: () => {
            saveColumns();
          },
        },
      });
    }

    this.dialog.confirm({
      message: i18n("boards.board.confirm_delete_column"),
      didConfirm: saveColumns,
    });
  }

  @action
  clearColumn(columnId) {
    const column = this.columns.find((col) => col.id === columnId);
    const cardCount = column?.cards?.length || 0;
    if (cardCount === 0) {
      return;
    }

    this.dialog.confirm({
      message: i18n("boards.board.confirm_clear_column", {
        count: cardCount,
        column_title: column.fancyTitle,
      }),
      didConfirm: async () => {
        const snapshot = this.columns.map((col) =>
          col.copy({ cards: [...col.cards] })
        );

        this.columns = this.columns.map((col) => {
          if (col.id === columnId) {
            return col.copy({ cards: [] });
          }
          return col;
        });

        try {
          await ajax(
            `/boards/api/boards/${this.board.id}/columns/${columnId}/cards`,
            {
              type: "DELETE",
              data: { client_id: this.messageBus.clientId },
            }
          );
        } catch (error) {
          this.columns = snapshot;
          popupAjaxError(error);
        }
      },
    });
  }

  // Board settings actions

  @action
  openBoardSettings(closeMenu) {
    closeMenu();
    this.#openBoardSettingsModal();
  }

  #openBoardSettingsModal({ updateUrl = true } = {}) {
    const boardUrl = boardsBoardUrl(this.board);

    if (updateUrl) {
      DiscourseURL.replaceState(boardsBoardConfigureUrl(this.board));
    }

    this.modal
      .show(BoardsBoardSettings, {
        model: {
          board: this.board,
          isNew: false,
          onSave: (boardData) => this.saveBoardSettings(boardData),
          onDelete: () => this.deleteBoard(),
        },
      })
      .then((result) => {
        if (!this.isDestroying && !this.isDestroyed) {
          DiscourseURL.replaceState(boardUrl);

          if (result?.reloadAfterSave) {
            reload();
          }
        }
      });
  }

  @action
  async saveBoardSettings(boardData) {
    const payload = {
      board: boardData,
    };

    const originalSlug = this.board.slug;

    const result = await ajax(`/boards/api/boards/${this.board.id}`, {
      type: "PUT",
      contentType: "application/json",
      data: JSON.stringify(payload),
    });

    if (result.board) {
      this.board = Board.create({ ...this.board, ...result.board });
    }

    this.toasts.success({
      data: { message: i18n("saved") },
      duration: "short",
    });

    if (this.board.slug && this.board.slug !== originalSlug) {
      this.router.replaceWith("boardsBoard", this.board.slug, this.board.id);
    }
  }

  @action
  deleteBoard(closeMenu) {
    closeMenu?.();
    this.dialog.confirm({
      message: i18n("boards.manage.confirm_delete"),
      didConfirm: async () => {
        try {
          await ajax(`/boards/api/boards/${this.board.id}`, {
            type: "DELETE",
          });
          this.router.transitionTo("boards");
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  goToAllBoards(closeMenu) {
    closeMenu?.();
    this.router.transitionTo("boards");
  }

  async _saveColumn(type, url, payload = {}) {
    await ajax(url, {
      type,
      contentType: "application/json",
      data: JSON.stringify({
        ...payload,
        client_id: this.messageBus.clientId,
      }),
    });

    this.toasts.success({
      data: { message: i18n("saved") },
      duration: "short",
    });

    await this.#handleBoardUpdated();
  }

  @bind
  _onTopicCreated(createdPost) {
    const cardId = this._promotingCardId;
    this._cleanupPromotion();
    this.onUpdateCard(cardId, { topic_id: createdPost.topic_id });
  }

  @bind
  _onRouteWillChange(transition) {
    if (this._promotingCardId) {
      transition.abort();
      this.#unbindPromotionRouteListener();
      this._promotingCardId = null;
    }
  }

  _cleanupPromotion() {
    this._promotingCardId = null;
    this.#unbindPromotionAppEventListeners();
    this.#unbindPromotionRouteListener();
  }

  #bindPromotionListeners() {
    if (!this._promotionAppEventListenersBound) {
      this.appEvents.on("topic:created", this, this._onTopicCreated);
      this.appEvents.on("composer:cancelled", this, this._cleanupPromotion);
      this._promotionAppEventListenersBound = true;
    }

    if (!this._promotionRouteListenerBound) {
      this.router.on("routeWillChange", this._onRouteWillChange);
      this._promotionRouteListenerBound = true;
    }
  }

  #unbindPromotionAppEventListeners() {
    if (!this._promotionAppEventListenersBound) {
      return;
    }

    this.appEvents.off("topic:created", this, this._onTopicCreated);
    this.appEvents.off("composer:cancelled", this, this._cleanupPromotion);
    this._promotionAppEventListenersBound = false;
  }

  #unbindPromotionRouteListener() {
    if (!this._promotionRouteListenerBound) {
      return;
    }

    this.router.off("routeWillChange", this._onRouteWillChange);
    this._promotionRouteListenerBound = false;
  }

  #findCard(cardId) {
    for (const col of this.columns) {
      const card = col.cards.find((c) => c.id === cardId);
      if (card) {
        return card;
      }
    }
    return null;
  }

  #focusHighlightCard(cardId) {
    if (!this.#findCard(cardId)) {
      return;
    }

    // The deep-linked card stays flagged for the lifetime of the board so a
    // card outside its column's recency window keeps rendering; only the pulse
    // highlight below is transient.
    this.linkedCardId = cardId;
    this.linkHighlightCardId = cardId;

    // next() rather than afterRender: this can be called mid-afterRender
    // flush, before the highlight class renders, and waitForAnimationEnd
    // would then see no animation and fall back to resolving immediately.
    next(this, async () => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      const cardElement = document.querySelector(
        `.discourse-boards-card[data-card-id="${cardId}"]`
      );
      cardElement?.scrollIntoView({ block: "center", inline: "center" });

      // With reduced motion there is no animation to wait for; the static
      // highlight stays as a persistent indicator instead.
      if (!cardElement || isTesting() || prefersReducedMotion()) {
        return;
      }

      await waitForAnimationEnd(cardElement);

      if (
        !this.isDestroying &&
        !this.isDestroyed &&
        this.linkHighlightCardId === cardId
      ) {
        this.linkHighlightCardId = null;
      }
    });
  }

  #openInitialCardModal(card) {
    const boardUrl = boardsBoardUrl(this.board);
    const isTopicCard = card.card_type === "topic" && card.topic;
    const ModalComponent = isTopicCard
      ? BoardsTopicCardDetailModal
      : BoardsCardDetailModal;
    let navigatedAway = false;

    const column = this.columns.find((col) => col.id === card.column_id);
    const model = isTopicCard
      ? {
          card,
          columnTitle: column?.fancyTitle,
          columnIcon: column?.icon,
          columnColor: column?.color,
          onNavigateAway: (url) => {
            navigatedAway = true;
            DiscourseURL.routeTo(url);
          },
        }
      : { card, canWrite: this.canWrite, onUpdateCard: this.onUpdateCard };

    this.modal.show(ModalComponent, { model }).finally(() => {
      if (!navigatedAway && !this.isDestroying && !this.isDestroyed) {
        DiscourseURL.replaceState(boardUrl);
      }
    });
  }

  _highlightDroppedCard(cardId) {
    this._clearDropHighlight();
    this.dropHighlightCardId = null;

    schedule("afterRender", () => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.dropHighlightCardId = cardId;
      if (isTesting()) {
        return;
      }

      this._dropHighlightTimeout = discourseLater(
        this,
        () => {
          if (this.dropHighlightCardId === cardId) {
            this.dropHighlightCardId = null;
          }
          this._dropHighlightTimeout = null;
        },
        1000
      );
    });
  }

  _clearDropHighlight() {
    if (this._dropHighlightTimeout) {
      cancel(this._dropHighlightTimeout);
      this._dropHighlightTimeout = null;
    }
  }

  <template>
    {{#if this.fullscreen}}
      {{bodyClass "discourse-boards-fullscreen"}}
    {{/if}}

    <div
      class="discourse-boards-board-viewer
        {{if this.fullscreen 'discourse-boards-board-viewer--fullscreen'}}"
      {{this.setupMessageBus}}
      {{onWindowResize calcAvailableHeight}}
      {{didInsert calcAvailableHeight}}
    >
      <div class="discourse-boards-board-viewer__header">
        <div class="discourse-boards-board-viewer__title-wrapper">
          <BackButton @route="boards" @label="boards.board.all_boards" />
          <h2
            class="discourse-boards-board-viewer__title"
          >{{this.board.fancyTitle}}</h2>

          <div class="discourse-boards-board-viewer__metadata">
            {{#if this.hasBoardFilters}}
              <div class="discourse-boards-board-viewer__constraint">
                {{#each this.boardCategories as |category|}}
                  {{dBoundCategoryLink category link=true}}
                {{/each}}
                {{#if this.boardTagNames.length}}
                  <div class="list-tags">
                    {{dDiscourseTags null tags=this.boardTagNames}}
                  </div>
                {{/if}}
                <DTooltip>
                  <:trigger>
                    {{dIcon "circle-info"}}
                  </:trigger>
                  <:content>
                    <span>{{i18n "boards.board.constraint_tooltip"}}</span>
                  </:content>
                </DTooltip>
              </div>
            {{/if}}
          </div>
        </div>

        <div class="discourse-boards-board-viewer__controls">
          <DMenu
            @identifier="boards-board-controls"
            @icon="ellipsis"
            @title="boards.board.controls"
            @triggerClass="btn-flat"
          >
            <:content as |args|>
              <DDropdownMenu as |dropdown|>
                {{#if this.canManage}}
                  <dropdown.item data-identifier="add-column">
                    <DButton
                      @action={{fn this.openAddColumnModal args.close}}
                      @icon="plus"
                      @label="boards.board.add_column"
                      class="btn-transparent"
                    />
                  </dropdown.item>
                  <dropdown.item data-identifier="board-settings">
                    <DButton
                      @action={{fn this.openBoardSettings args.close}}
                      @icon="gear"
                      @label="boards.board.board_settings"
                      class="btn-transparent"
                    />
                  </dropdown.item>
                  <dropdown.item data-identifier="delete-board">
                    <DButton
                      @action={{fn this.deleteBoard args.close}}
                      @icon="trash-can"
                      @label="boards.board.delete_board"
                      class="btn-transparent btn-danger"
                    />
                  </dropdown.item>
                {{/if}}
              </DDropdownMenu>
            </:content>
          </DMenu>
          {{#if this.fullscreen}}
            <DButton
              @action={{this.exitFullscreen}}
              @icon="discourse-compress"
              @title="boards.board.exit_fullscreen"
              class="btn-flat discourse-boards-board-viewer__exit-fullscreen"
            />
          {{else}}
            <DButton
              @action={{this.toggleFullscreen}}
              @icon="discourse-expand"
              @title="boards.board.fullscreen"
              class="btn-flat"
            />
          {{/if}}
        </div>
      </div>

      {{#if this.columns.length}}
        <div
          class="discourse-boards-board-container"
          {{on "dragover" this.dragOverBoardContainer}}
          {{on "dragleave" this.dragLeaveBoardContainer}}
          {{on "drop" this.dropBoardContainer}}
          {{dragToScroll}}
        >
          {{#each this.columns key="id" as |column|}}
            <BoardsColumn
              @column={{column}}
              @board={{this.board}}
              @canWrite={{this.canWrite}}
              @canManage={{this.canManage}}
              @allSameCategory={{this.allSameCategory}}
              @dropHighlightCardId={{this.dropHighlightCardId}}
              @linkHighlightCardId={{this.linkHighlightCardId}}
              @linkedCardId={{this.linkedCardId}}
              @dragData={{this.dragData}}
              @onDragStart={{this.onDragStart}}
              @onDragEnd={{this.onDragEnd}}
              @onDrop={{this.onDrop}}
              @onAddCard={{this.onAddCard}}
              @onUpdateCard={{this.onUpdateCard}}
              @onDeleteCard={{this.onDeleteCard}}
              @onPromoteToTopic={{this.onPromoteToTopic}}
              @onRefreshBoard={{this.refreshBoard}}
              @onEditColumn={{this.openEditColumnModal}}
              @onMoveColumn={{this.moveColumn}}
              @onDeleteColumn={{this.deleteColumn}}
              @onClearColumn={{this.clearColumn}}
              @allColumns={{this.columns}}
            />
          {{/each}}
          {{#if this.canManage}}
            <button
              type="button"
              class="discourse-boards-board-container__add-column"
              title={{i18n "boards.board.add_column"}}
              {{on "click" this.openAddColumnModal}}
              {{matchLastColumnHeight}}
            >
              {{dIcon "plus"}}
            </button>
          {{/if}}
        </div>
      {{else}}
        <div class="discourse-boards-board-viewer__empty">
          <div class="discourse-boards-board-viewer__empty-column">
            {{dIcon "table-columns"}}
            <h3>{{i18n "boards.board.empty_board"}}</h3>
            <p>{{i18n "boards.board.empty_board_cta"}}</p>
            {{#if this.canManage}}
              <DButton
                @action={{this.openAddColumnModal}}
                @icon="plus"
                @label="boards.board.add_column"
                class="btn-primary"
              />
            {{/if}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
