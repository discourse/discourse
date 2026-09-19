import { iconHTML } from "discourse/lib/icon-library";
import { applyValueTransformer } from "discourse/lib/transformer";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import { boardsBoardUrl } from "./boards-urls";

export const MULTI_BOARD_TRIGGER_SELECTOR =
  ".discourse-boards-topic-pill--multiple";

// Fields written per card, and read back by `membershipsFor`
const CARD_FIELDS = [
  "board-id",
  "board-name",
  "board-slug",
  "card-id",
  "column-title",
  "column-color",
  "column-icon",
];

export function membershipCardUrl(membership) {
  const boardUrl = boardsBoardUrl({
    slug: membership.board_slug,
    id: membership.board_id,
  });
  return `${boardUrl}?card=${membership.cards[0].card_id}`;
}

export function membershipTitle(membership) {
  const boardName = membership.unicode_board_name || membership.board_name;

  if (membership.cards.length > 1) {
    return i18n("boards.topic_pill.title_multiple_columns", {
      board: boardName,
      count: membership.cards.length,
    });
  }

  return i18n("boards.topic_pill.title", {
    board: boardName,
    column:
      membership.cards[0].unicode_column_title ||
      membership.cards[0].column_title,
  });
}

/** Regroups what `boardData` wrote out, for the menu the pill opens. */
export function membershipsFor(trigger) {
  const boards = new Map();
  const count = Number(trigger.dataset.cardCount);

  for (let index = 0; index < count; index++) {
    // absent attributes stay undefined, so an uncoloured or iconless column
    // reads back the way the serializer sent it
    const field = (name) =>
      trigger.getAttribute(`data-card-${index}-${name}`) ?? undefined;

    const boardId = field("board-id");
    let board = boards.get(boardId);

    if (!board) {
      board = {
        board_id: Number(boardId),
        board_name: field("board-name"),
        board_slug: field("board-slug"),
        cards: [],
      };
      boards.set(boardId, board);
    }

    board.cards.push({
      card_id: Number(field("card-id")),
      column_title: field("column-title"),
      column_color: field("column-color"),
      column_icon: field("column-icon"),
    });
  }

  return [...boards.values()];
}

function attrs(attributes) {
  return Object.entries(attributes)
    .filter(([, value]) => value !== undefined && value !== null)
    .map(([name, value]) => ` ${name}="${escapeExpression(value)}"`)
    .join("");
}

function pill(tagName, { extraClass, label, ...attributes }) {
  const className = [
    "discourse-boards-topic-pill",
    "discourse-tag",
    "simple",
    extraClass,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    `<${tagName}${attrs({ class: className, ...attributes })}>` +
    iconHTML("table-columns") +
    `<span class="discourse-boards-topic-pill__label">${escapeExpression(label)}</span>` +
    `</${tagName}>`
  );
}

function boardPill(membership, tagName) {
  const link =
    tagName === "a"
      ? { href: membershipCardUrl(membership), "data-auto-route": "true" }
      : {};

  return pill(tagName, {
    label: membership.unicode_board_name || membership.board_name,
    title: membershipTitle(membership),
    ...link,
  });
}

// The menu is opened by a delegated listener, which has only the element to go
// on, so the boards ride along in data attributes the way discourse-local-dates
// carries its date config.
function boardData(memberships) {
  const cards = memberships.flatMap((membership) =>
    membership.cards.map((card) => ({
      "board-id": membership.board_id,
      "board-name": membership.unicode_board_name || membership.board_name,
      "board-slug": membership.board_slug,
      "card-id": card.card_id,
      "column-title": card.unicode_column_title || card.column_title,
      "column-color": card.column_color,
      "column-icon": card.column_icon,
    }))
  );

  return Object.fromEntries([
    ["data-card-count", cards.length],
    ...cards.flatMap((card, index) =>
      CARD_FIELDS.map((name) => [`data-card-${index}-${name}`, card[name]])
    ),
  ]);
}

function multiBoardPill(memberships) {
  return pill("a", {
    extraClass: "discourse-boards-topic-pill--multiple",
    label: i18n("boards.topic_pill.multiple", {
      count: memberships.length,
    }),
    title: i18n("boards.topic_pill.multiple_title"),
    role: "button",
    tabindex: "0",
    "aria-haspopup": "true",
    "aria-expanded": "false",
    ...boardData(memberships),
  });
}

export function boardsTagsHtml(topic, params) {
  const memberships = topic.board_memberships;
  if (!memberships?.length) {
    return;
  }

  const tagName = params?.tagName || "a";

  if (memberships.length > 1 && tagName === "a") {
    return multiBoardPill(memberships);
  }

  return memberships
    .map((membership, index) => {
      let html = boardPill(membership, tagName);

      if (index < memberships.length - 1) {
        const separator = applyValueTransformer("tag-separator", ",", {
          topic,
          index,
        });
        html += `<span class="discourse-tags__tag-separator">${separator}</span>`;
      }

      return html;
    })
    .join("");
}
