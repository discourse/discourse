import { LOADING_ONEBOX_CSS_CLASS, load } from "pretty-text/oneboxer";
import { applyInlineOneboxes } from "pretty-text/inline-oneboxer";

export function loadOneboxes(
  container,
  ajax,
  topicId,
  categoryId,
  maxOneboxes,
  refresh
) {
  const oneboxes = {};
  const inlineOneboxes = {};

  // Oneboxes = `a.onebox` -> `a.onebox-loading` -> `aside.onebox`
  // Inline Oneboxes = `a.inline-onebox-loading` -> `a.inline-onebox`

  let loadedOneboxes = container.querySelectorAll(
    `aside.onebox, a.${LOADING_ONEBOX_CSS_CLASS}, a.inline-onebox`
  ).length;

  container
    .querySelectorAll(`a.onebox, a.inline-onebox-loading`)
    .forEach((link) => {
      const text = link.textContent;
      const isInline = link.getAttribute("class") === "inline-onebox-loading";
      const m = isInline ? inlineOneboxes : oneboxes;

      if (loadedOneboxes < maxOneboxes) {
        if (m[text] === undefined) {
          m[text] = [];
          loadedOneboxes++;
        }
        m[text].push(link);
      } else {
        if (m[text] !== undefined) {
          m[text].push(link);
        } else if (isInline) {
          link.classList.remove("inline-onebox-loading");
        }
      }
    });

  let newBoxes = 0;

  if (Object.keys(oneboxes).length > 0) {
    _loadOneboxes(oneboxes, ajax, newBoxes, topicId, categoryId, refresh);
  }

  if (Object.keys(inlineOneboxes).length > 0) {
    _loadInlineOneboxes(inlineOneboxes, ajax, topicId, categoryId);
  }

  return newBoxes;
}

function _loadInlineOneboxes(inline, ajax, topicId, categoryId) {
  applyInlineOneboxes(inline, ajax, {
    categoryId: topicId,
    topicId: categoryId,
  });
}

function _loadOneboxes(oneboxes, ajax, count, topicId, categoryId, refresh) {
  Object.values(oneboxes).forEach((onebox) => {
    onebox.forEach((o) => {
      load({
        elem: o,
        refresh,
        ajax,
        categoryId: categoryId,
        topicId: topicId,
      });

      count++;
    });
  });
}
