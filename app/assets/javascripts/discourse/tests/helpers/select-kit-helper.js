import { moduleForComponent } from "ember-qunit";
import { isEmpty } from "@ember/utils";
import { click, fillIn } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";

function checkSelectKitIsNotExpanded(selector) {
  if (find(selector).hasClass("is-expanded")) {
    // eslint-disable-next-line no-console
    console.warn("You expected select-kit to be collapsed but it is expanded.");
  }
}

function checkSelectKitIsNotCollapsed(selector) {
  if (!find(selector).hasClass("is-expanded")) {
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
    find(`${selector} .filter-input`).val() + filter
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
  await click(find(`${selector} .select-kit-row`).eq(index));
}

async function keyboardHelper(value, target, selector) {
  target = find(selector).find(target || ".filter-input");

  if (value === "selectAll") {
    // special casing the only one not working with triggerEvent
    const event = jQuery.Event("keydown");
    event.keyCode = 65;
    event.metaKey = true;
    target.trigger(event);
  } else {
    const mapping = {
      enter: { keyCode: 13 },
      backspace: { keyCode: 8 },
      escape: { keyCode: 27 },
      down: { keyCode: 40 },
      up: { keyCode: 38 },
      tab: { keyCode: 9 },
    };

    await triggerEvent(
      target,
      "keydown",
      mapping[value] || { keyCode: value.charCodeAt(0) }
    );
  }
}

function rowHelper(row) {
  return {
    name() {
      return row.attr("data-name");
    },
    icon() {
      return row.find(".d-icon");
    },
    title() {
      return row.attr("title");
    },
    label() {
      return row.find(".name").text().trim();
    },
    value() {
      const value = row.attr("data-value");
      return isEmpty(value) ? null : value;
    },
    exists() {
      return exists(row);
    },
    el() {
      return row;
    },
  };
}

function headerHelper(header) {
  return {
    value() {
      const value = header.attr("data-value");
      return isEmpty(value) ? null : value;
    },
    name() {
      return header.attr("data-name");
    },
    label() {
      return header.text().trim();
    },
    icon() {
      return header.find(".d-icon");
    },
    title() {
      return header.find(".selected-name").attr("title");
    },
    el() {
      return header;
    },
  };
}

function filterHelper(filter) {
  return {
    icon() {
      return filter.find(".d-icon");
    },
    exists() {
      return exists(filter);
    },
    value() {
      return filter.find("input").val();
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
      return find(selector).hasClass("is-expanded");
    },

    isFocused() {
      return find(selector).hasClass("is-focused");
    },

    isHidden() {
      return find(selector).hasClass("is-hidden");
    },

    header() {
      return headerHelper(find(selector).find(".select-kit-header"));
    },

    filter() {
      return filterHelper(find(selector).find(".select-kit-filter"));
    },

    rows() {
      return find(selector).find(".select-kit-row");
    },

    displayedContent() {
      return this.rows()
        .map((_, row) => {
          return {
            name: row.getAttribute("data-name"),
            id: row.getAttribute("data-value"),
          };
        })
        .toArray();
    },

    rowByValue(value) {
      return rowHelper(
        find(selector).find('.select-kit-row[data-value="' + value + '"]')
      );
    },

    rowByName(name) {
      return rowHelper(
        find(selector).find('.select-kit-row[data-name="' + name + '"]')
      );
    },

    rowByIndex(index) {
      return rowHelper(
        find(selector).find(".select-kit-row:eq(" + index + ")")
      );
    },

    el() {
      return find(selector);
    },

    noneRow() {
      return rowHelper(find(selector).find(".select-kit-row.none"));
    },

    validationMessage() {
      const validationMessage = find(selector).find(".validation-message");

      if (validationMessage.length) {
        return validationMessage.html().trim();
      } else {
        return null;
      }
    },

    selectedRow() {
      return rowHelper(find(selector).find(".select-kit-row.is-selected"));
    },

    highlightedRow() {
      return rowHelper(find(selector).find(".select-kit-row.is-highlighted"));
    },

    async deselectItem(value) {
      await click(
        find(selector).find(".select-kit-header").find(`[data-value=${value}]`)
      );
    },

    exists() {
      return exists(selector);
    },
  };
}

export function testSelectKitModule(moduleName, options = {}) {
  moduleForComponent(`select-kit/${moduleName}`, {
    integration: true,

    beforeEach() {
      this.set("subject", selectKit());
      options.beforeEach && options.beforeEach.call(this);
    },

    afterEach() {
      options.afterEach && options.afterEach.call(this);
    },
  });
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
