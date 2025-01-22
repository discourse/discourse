import { click, fillIn, triggerEvent } from "@ember/test-helpers";
import { isEmpty } from "@ember/utils";
import $ from "jquery";
import { exists, query, queryAll } from "discourse/tests/helpers/qunit-helpers";

function checkSelectKitIsNotExpanded(selector) {
  if (query(selector).classList.contains("is-expanded")) {
    // eslint-disable-next-line no-console
    console.warn("You expected select-kit to be collapsed but it is expanded.");
  }
}

function checkSelectKitIsNotCollapsed(selector) {
  if (!query(selector).classList.contains("is-expanded")) {
    // eslint-disable-next-line no-console
    console.warn("You expected select-kit to be expanded but it is collapsed.");
  }
}

async function expandSelectKit(selector) {
  checkSelectKitIsNotExpanded(selector);
  return await click(`${selector} .select-kit-header`);
}

async function collapseSelectKit(selector) {
  checkSelectKitIsNotCollapsed(selector);
  return await click(`${selector} .select-kit-header`);
}

async function selectKitFillInFilter(filter, selector) {
  checkSelectKitIsNotCollapsed(selector);
  await fillIn(
    `${selector} .filter-input`,
    query(`${selector} .filter-input`).value + filter
  );
}

async function selectKitEmptyFilter(selector) {
  checkSelectKitIsNotCollapsed(selector);
  await fillIn(`${selector} .filter-input`, "");
}

async function selectKitSelectRowByValue(value, selector) {
  checkSelectKitIsNotCollapsed(selector);
  await click(`${selector} .select-kit-row[data-value='${value}']`);
}

async function selectKitSelectRowByName(name, selector) {
  checkSelectKitIsNotCollapsed(selector);
  await click(`${selector} .select-kit-row[data-name='${name}']`);
}

async function selectKitSelectNoneRow(selector) {
  checkSelectKitIsNotCollapsed(selector);
  await click(`${selector} .select-kit-row.none`);
}

async function selectKitSelectRowByIndex(index, selector) {
  checkSelectKitIsNotCollapsed(selector);
  await click(queryAll(`${selector} .select-kit-row`)[index]);
}

async function keyboardHelper(value, target, selector) {
  target = query(selector).querySelector(target || ".filter-input");

  if (value === "selectAll") {
    // special casing the only one not working with triggerEvent
    const event = $.Event("keydown");
    event.key = "A";
    event.keyCode = 65;
    event.metaKey = true;
    $(target).trigger(event);
  } else {
    const mapping = {
      enter: { key: "Enter", keyCode: 13 },
      backspace: { key: "Backspace", keyCode: 8 },
      escape: { key: "Escape", keyCode: 27 },
      down: { key: "ArrowDown", keyCode: 40 },
      up: { key: "ArrowUp", keyCode: 38 },
      tab: { key: "Tab", keyCode: 9 },
    };

    await triggerEvent(
      target,
      "keydown",
      mapping[value.toLowerCase()] || {
        key: value,
        keyCode: value.charCodeAt(0),
      }
    );
  }
}

function rowHelper(row) {
  return {
    name() {
      return row.getAttribute("data-name");
    },
    icon() {
      return row.querySelector(".d-icon");
    },
    title() {
      return row.getAttribute("title");
    },
    label() {
      return row.querySelector(".name").innerText.trim();
    },
    description() {
      return row.querySelector(".desc").innerText.trim();
    },
    value() {
      const value = row?.getAttribute("data-value");
      return isEmpty(value) ? null : value;
    },
    exists() {
      return exists(row);
    },
    el() {
      return row;
    },
    hasClass(className) {
      return row.classList.contains(className);
    },
  };
}

function headerHelper(header) {
  return {
    value() {
      const value = header.getAttribute("data-value");
      return isEmpty(value) ? null : value;
    },
    name() {
      return header.getAttribute("data-name");
    },
    label() {
      return header.innerText
        .trim()
        .replace(/(^[\s\u200b]*|[\s\u200b]*$)/g, "");
    },
    icon() {
      return header.querySelector(".d-icon");
    },
    title() {
      return header.querySelector(".selected-name").getAttribute("title");
    },
    el() {
      return header;
    },
  };
}

function filterHelper(filter) {
  return {
    icon() {
      return filter.querySelector(".d-icon");
    },
    exists() {
      return exists(filter);
    },
    value() {
      return filter.querySelector("input").value;
    },
    el() {
      return filter;
    },
  };
}

export default function selectKit(selector) {
  selector = selector || ".select-kit";

  return {
    async expand() {
      await expandSelectKit(selector);
    },

    async collapse() {
      await collapseSelectKit(selector);
    },

    async selectRowByIndex(index) {
      await selectKitSelectRowByIndex(index, selector);
    },

    async selectRowByValue(value) {
      await selectKitSelectRowByValue(value, selector);
    },

    async selectKitSelectRowByName(name) {
      await selectKitSelectRowByName(name, selector);
    },

    async selectRowByName(name) {
      await selectKitSelectRowByName(name, selector);
    },

    async selectNoneRow() {
      await selectKitSelectNoneRow(selector);
    },

    async fillInFilter(filter) {
      await selectKitFillInFilter(filter, selector);
    },

    async emptyFilter() {
      await selectKitEmptyFilter(selector);
    },

    async keyboard(value, target) {
      await keyboardHelper(value, target, selector);
    },

    isExpanded() {
      return query(selector).classList.contains("is-expanded");
    },

    isFocused() {
      return query(selector).classList.contains("is-focused");
    },

    isHidden() {
      return query(selector).classList.contains("is-hidden");
    },

    isDisabled() {
      return query(selector).classList.contains("is-disabled");
    },

    header() {
      return headerHelper(query(selector).querySelector(".select-kit-header"));
    },

    filter() {
      return filterHelper(query(selector).querySelector(".select-kit-filter"));
    },

    error() {
      return query(selector).querySelector(".select-kit-error");
    },

    rows() {
      return query(selector).querySelectorAll(".select-kit-row");
    },

    displayedContent() {
      return [...this.rows()].map((row) => ({
        name: row.getAttribute("data-name"),
        id: row.getAttribute("data-value"),
      }));
    },

    rowByValue(value) {
      return rowHelper(
        query(selector).querySelector(`.select-kit-row[data-value="${value}"]`)
      );
    },

    rowByName(name) {
      return rowHelper(
        query(selector).querySelector(`.select-kit-row[data-name="${name}"]`)
      );
    },

    rowByIndex(index) {
      return rowHelper(
        query(selector).querySelector(
          `.select-kit-row:nth-of-type(${index + 1})`
        )
      );
    },

    el() {
      return query(selector);
    },

    noneRow() {
      return rowHelper(query(selector).querySelector(".select-kit-row.none"));
    },

    clearButton() {
      return query(selector).querySelector(".btn-clear");
    },

    validationMessage() {
      const validationMessage = query(selector).querySelector(
        ".validation-message"
      );

      if (validationMessage) {
        return validationMessage.innerHTML.trim();
      } else {
        return null;
      }
    },

    selectedRow() {
      return rowHelper(
        query(selector).querySelector(".select-kit-row.is-selected")
      );
    },

    highlightedRow() {
      return rowHelper(
        query(selector).querySelector(".select-kit-row.is-highlighted")
      );
    },

    async deselectItemByValue(value) {
      await click(`${selector} .selected-content [data-value="${value}"]`);
    },

    async deselectItemByName(name) {
      await click(`${selector} .selected-content [data-name="${name}"]`);
    },

    async deselectItemByIndex(index) {
      await click(
        queryAll(`${selector} .selected-content .selected-choice`)[index]
      );
    },

    exists() {
      return exists(selector);
    },
  };
}

export const DEFAULT_CONTENT = [
  { id: 1, name: "foo" },
  { id: 2, name: "bar" },
  { id: 3, name: "baz" },
];

export function setDefaultState(ctx, value, options = {}) {
  const properties = Object.assign(
    {
      value,
      onChange: (v) => {
        ctx.set("value", v);
      },
    },
    options || {}
  );

  ctx.setProperties(properties);
}
