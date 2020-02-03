import { isEmpty } from "@ember/utils";

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
      tab: { keyCode: 9 }
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
    value() {
      const value = row.attr("data-value");
      return isEmpty(value) ? null : value;
    },
    exists() {
      return exists(row);
    },
    el() {
      return row;
    }
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
      return header.attr("title");
    },
    el() {
      return header;
    }
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
    }
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
      await selectKitSelectRowByValue(name, selector);
    },

    async selectNoneRow() {
      await selectKitSelectNoneRow(selector);
    },

    async fillInFilter(filter) {
      await selectKitFillInFilter(filter, selector);
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
            id: row.getAttribute("data-value")
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

    exists() {
      return exists(selector);
    }
  };
}
