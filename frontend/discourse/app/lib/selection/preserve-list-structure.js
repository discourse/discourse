/**
 * List structure preservation for selection/quote operations.
 *
 * When users select content that includes list items, the browser's
 * cloneContents() may produce orphan <li> elements without their parent
 * lists. This module reconstructs proper list structure while preserving
 * the original list types (ordered vs unordered) and attributes.
 */

import {
  createListWrapper,
  findParentList,
  getListStartNumber,
  isListTight,
  setTightAttributeOnAllLists,
} from "discourse/lib/list-utils";

/**
 * States for the orphan run collector state machine.
 * @readonly
 * @enum {string}
 */
const CollectorState = {
  IDLE: "idle",
  COLLECTING: "collecting",
};

function closestElement(node) {
  while (node && node.nodeType !== Node.ELEMENT_NODE) {
    node = node.parentNode;
  }
  return node;
}

function getStartElementFromRange(range) {
  return closestElement(range.startContainer);
}

function hasTopLevelListItems(container) {
  for (const node of container.childNodes) {
    if (node.nodeName === "LI") {
      return true;
    }
  }
  return false;
}

function wrapLeadingNonListContent(container) {
  const nodesToWrap = [];
  for (const node of container.childNodes) {
    if (node.nodeName === "LI") {
      break;
    }
    nodesToWrap.push(node);
  }
  if (nodesToWrap.length === 0) {
    return;
  }
  const listItem = document.createElement("li");
  const firstLi = container.querySelector(":scope > li");
  container.insertBefore(listItem, firstLi);
  nodesToWrap.forEach((node) => listItem.appendChild(node));
}

function wrapContainerContentsInListItem(
  container,
  listTagName,
  startNumber,
  isTight
) {
  const listItem = document.createElement("li");
  while (container.firstChild) {
    listItem.appendChild(container.firstChild);
  }
  const list = createListWrapper(listTagName, startNumber, isTight);
  list.appendChild(listItem);
  container.appendChild(list);
}

/**
 * Determines if a node is a separator that should break an LI run.
 * Whitespace-only text nodes are NOT separators (ignored).
 * All other non-LI nodes ARE separators.
 *
 * @param {Node} node - The node to check
 * @returns {boolean} True if the node should end the current run
 */
function isSeparatorNode(node) {
  if (node.nodeName === "LI") {
    return false;
  }
  if (node.nodeType === Node.TEXT_NODE) {
    return /\S/.test(node.textContent);
  }
  // All other nodes (elements, comments, etc.) are separators
  return true;
}

/**
 * Collects contiguous runs of orphan <li> elements from a container.
 * Uses an explicit state machine:
 * - IDLE: Looking for an <li> to start a new run
 * - COLLECTING: Accumulating <li> elements until a separator is found
 *
 * Whitespace-only text nodes are ignored and don't break runs.
 * Any other non-<li> node (including <br>, <p>, non-whitespace text) breaks the run.
 *
 * @param {Element} container - Container with potential orphan <li> elements
 * @returns {Array<HTMLElement[]>} Array of runs, each run being an array of <li> elements
 */
export function collectContiguousOrphanRuns(container) {
  const runs = [];
  let currentRun = [];
  let state = CollectorState.IDLE;

  for (const node of container.childNodes) {
    const isListItem = node.nodeName === "LI";
    const isSeparator = isSeparatorNode(node);

    switch (state) {
      case CollectorState.IDLE:
        if (isListItem) {
          currentRun = [node];
          state = CollectorState.COLLECTING;
        }
        break;

      case CollectorState.COLLECTING:
        if (isListItem) {
          currentRun.push(node);
        } else if (isSeparator) {
          runs.push(currentRun);
          currentRun = [];
          state = CollectorState.IDLE;
        }
        // Whitespace text nodes: stay in COLLECTING, don't add to run
        break;
    }
  }

  // Flush any remaining run
  if (state === CollectorState.COLLECTING && currentRun.length > 0) {
    runs.push(currentRun);
  }

  return runs;
}

function wrapOrphanListItems(container, listTagName, startNumber, isTight) {
  const runs = collectContiguousOrphanRuns(container);
  if (runs.length === 0) {
    return;
  }

  let currentStart = startNumber;
  for (const run of runs) {
    const list = createListWrapper(listTagName, currentStart, isTight);
    run[0].parentNode.insertBefore(list, run[0]);
    run.forEach((li) => list.appendChild(li));
    if (listTagName === "OL") {
      currentStart += run.length;
    }
  }
}

/**
 * Splits a run of orphan list items into sub-runs based on their original
 * list type (stored in data-original-list-tag attribute).
 *
 * @param {HTMLElement[]} run - Array of <li> elements
 * @returns {Array<{items: HTMLElement[], listTag: string, startNumber: number, isTight: boolean}>}
 */
function splitRunByOriginalListType(run) {
  const subRuns = [];
  let currentSubRun = null;

  for (const li of run) {
    const listTag = li.dataset.originalListTag || "UL";
    const startNumber = parseInt(li.dataset.originalStartNumber || "1", 10);
    const isTight = li.dataset.originalIsTight === "true";

    if (
      !currentSubRun ||
      currentSubRun.listTag !== listTag ||
      (listTag === "OL" &&
        startNumber !== currentSubRun.startNumber + currentSubRun.items.length)
    ) {
      currentSubRun = { items: [li], listTag, startNumber, isTight };
      subRuns.push(currentSubRun);
    } else {
      currentSubRun.items.push(li);
    }
  }

  return subRuns;
}

/**
 * Wraps orphan list items while respecting their original list types.
 * This handles selections that span multiple lists of different types.
 *
 * @param {HTMLElement} container - The container with orphan <li> elements
 */
function wrapOrphanListItemsByOriginalType(container) {
  const runs = collectContiguousOrphanRuns(container);
  if (runs.length === 0) {
    return;
  }

  for (const run of runs) {
    const hasAnnotations = run.some((li) => li.dataset.originalListTag);

    if (hasAnnotations) {
      const subRuns = splitRunByOriginalListType(run);
      for (const subRun of subRuns) {
        const list = createListWrapper(
          subRun.listTag,
          subRun.startNumber,
          subRun.isTight
        );
        subRun.items[0].parentNode.insertBefore(list, subRun.items[0]);
        subRun.items.forEach((li) => {
          delete li.dataset.originalListTag;
          delete li.dataset.originalStartNumber;
          delete li.dataset.originalIsTight;
          list.appendChild(li);
        });
      }
    } else {
      const list = createListWrapper("UL", 1, true);
      run[0].parentNode.insertBefore(list, run[0]);
      run.forEach((li) => list.appendChild(li));
    }
  }
}

function annotateOrphanListItem(orphanLi, originalLi) {
  const parentList = originalLi.parentElement;
  if (!(parentList?.tagName === "OL" || parentList?.tagName === "UL")) {
    return;
  }

  orphanLi.dataset.originalListTag = parentList.tagName;
  orphanLi.dataset.originalStartNumber = String(
    getListStartNumber(parentList, originalLi)
  );
  orphanLi.dataset.originalIsTight = String(isListTight(parentList));
}

/**
 * Annotates orphan list items in the cloned content with their original list info.
 * This looks up each <li> in the original DOM to find its parent list type.
 *
 * @param {HTMLElement} container - Container with cloned content
 * @param {Range} range - The original selection range
 */
function annotateOrphanListItemsWithOriginalInfo(container, range) {
  const orphanLis = Array.from(container.querySelectorAll(":scope > li"));
  if (orphanLis.length === 0) {
    return;
  }

  const commonAncestor =
    range.commonAncestorContainer.nodeType === Node.ELEMENT_NODE
      ? range.commonAncestorContainer
      : range.commonAncestorContainer.parentElement;

  const originalListItems = Array.from(commonAncestor.querySelectorAll("li"));
  let selectionListItems = originalListItems;

  if (typeof range.intersectsNode === "function") {
    selectionListItems = originalListItems.filter((li) => {
      try {
        return range.intersectsNode(li);
      } catch {
        return false;
      }
    });
  }

  if (selectionListItems.length === orphanLis.length) {
    for (let i = 0; i < orphanLis.length; i++) {
      annotateOrphanListItem(orphanLis[i], selectionListItems[i]);
    }
    return;
  }

  const remaining = selectionListItems.length
    ? [...selectionListItems]
    : [...originalListItems];

  for (const orphanLi of orphanLis) {
    const orphanText = orphanLi.textContent.trim();
    const matchIndex = remaining.findIndex(
      (originalLi) => originalLi.textContent.trim() === orphanText
    );

    if (matchIndex === -1) {
      continue;
    }

    annotateOrphanListItem(orphanLi, remaining[matchIndex]);
    remaining.splice(matchIndex, 1);
  }
}

/**
 * Preserves list structure when content is cloned from a selection.
 * Handles three scenarios:
 * 1. Selection starts inside a list item - wrap content appropriately
 * 2. Selection contains orphan <li> elements - wrap in their original list types
 * 3. Selection spans multiple lists - preserve each list's type
 *
 * @param {HTMLElement} container - Container with cloned selection content
 * @param {Range} range - The original selection range
 */
export function preserveListStructureInClonedContent(container, range) {
  const startElement = getStartElementFromRange(range);
  const originalListItem = startElement?.closest("li");

  if (hasTopLevelListItems(container)) {
    annotateOrphanListItemsWithOriginalInfo(container, range);
  }

  if (originalListItem) {
    const parentList = originalListItem.parentElement;
    const isParentAList =
      parentList?.tagName === "OL" || parentList?.tagName === "UL";

    if (!isParentAList) {
      return;
    }

    const listTagName = parentList.tagName;
    const startNumber = getListStartNumber(parentList, originalListItem);
    const isTight = isListTight(parentList);

    const firstElementChild = container.firstElementChild;
    const isAlreadyWrappedInCorrectList =
      firstElementChild?.tagName === listTagName &&
      !hasTopLevelListItems(container);

    if (isAlreadyWrappedInCorrectList) {
      if (listTagName === "OL" && startNumber !== 1) {
        firstElementChild.setAttribute("start", String(startNumber));
      }
      if (isTight) {
        firstElementChild.setAttribute("data-tight", "true");
      }
    } else if (hasTopLevelListItems(container)) {
      wrapLeadingNonListContent(container);
      wrapOrphanListItemsByOriginalType(container);
    } else {
      wrapContainerContentsInListItem(
        container,
        listTagName,
        startNumber,
        isTight
      );
    }
  } else {
    if (hasTopLevelListItems(container)) {
      wrapLeadingNonListContent(container);
      wrapOrphanListItemsByOriginalType(container);
    } else {
      const originalList = findParentList(startElement);
      if (originalList) {
        const startNumber = getListStartNumber(originalList, null);
        const isTight = isListTight(originalList);
        wrapOrphanListItems(
          container,
          originalList.tagName,
          startNumber,
          isTight
        );
      }
    }
  }
}

/**
 * Processes a cloned fragment for list structure preservation.
 * This is the main entry point used by selectedText().
 *
 * @param {HTMLElement} container - Container with cloned selection content
 * @param {Range} range - The original selection range
 */
export function processSelectionFragment(container, range) {
  preserveListStructureInClonedContent(container, range);
  setTightAttributeOnAllLists(container);
}
