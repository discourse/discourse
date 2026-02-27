const MSO_LIST_CLASSES = [
  "MsoListParagraphCxSpFirst",
  "MsoListParagraphCxSpMiddle",
  "MsoListParagraphCxSpLast",
];

/**
 * Extracts the list level from a Word list paragraph's style attribute.
 * Word uses styles like "mso-list:l0 level2 lfo1" to indicate nesting.
 *
 * @param {Element} element - The paragraph element
 * @returns {number} The list level (1-based)
 */
function extractListLevel(element) {
  const style = element.getAttribute("style") || "";
  const match = style.match(/level(\d+)/);
  return match ? parseInt(match[1], 10) : 1;
}

/**
 * Detects if a Word list paragraph represents an ordered (numbered) list.
 * Inspects the marker span content before deletion to determine list type.
 *
 * @param {Element} element - The paragraph element
 * @returns {{isOrdered: boolean, startNumber: number}} List type info
 */
function detectListType(element) {
  // Look for the marker span with mso-list:Ignore
  const markerSpan = element.querySelector('[style*="mso-list:Ignore"]');
  if (markerSpan) {
    const markerText = markerSpan.textContent.trim();
    // Check for numbered patterns: "1.", "1)", "a.", "a)", "i.", "I.", etc.
    // Ordered list markers typically end with . or ) and start with number or letter
    const numberedMatch = markerText.match(/^(\d+)[.)]/);
    if (numberedMatch) {
      return { isOrdered: true, startNumber: parseInt(numberedMatch[1], 10) };
    }
    // Letter-based ordered lists (a., b., A., B.)
    if (/^[a-zA-Z][.)]/.test(markerText)) {
      return { isOrdered: true, startNumber: 1 };
    }
    // Roman numerals (i., ii., I., II.)
    if (/^[ivxIVX]+[.)]/.test(markerText)) {
      return { isOrdered: true, startNumber: 1 };
    }
  }

  // Check IE conditional comments for markers
  const html = element.innerHTML;
  const conditionalMatch = html.match(
    /<!\[if !supportLists\]>([\s\S]*?)<!\[endif\]>/i
  );
  if (conditionalMatch) {
    const markerText = conditionalMatch[1].replace(/<[^>]*>/g, "").trim();
    const numberedMatch = markerText.match(/^(\d+)[.)]/);
    if (numberedMatch) {
      return { isOrdered: true, startNumber: parseInt(numberedMatch[1], 10) };
    }
    if (/^[a-zA-Z][.)]/.test(markerText)) {
      return { isOrdered: true, startNumber: 1 };
    }
    if (/^[ivxIVX]+[.)]/.test(markerText)) {
      return { isOrdered: true, startNumber: 1 };
    }
  }

  // Default to unordered (bullet) list
  return { isOrdered: false, startNumber: 1 };
}

/**
 * Extracts the text content from a Word list paragraph, removing
 * the bullet/number markers that Word includes.
 *
 * @param {Element} element - The paragraph element
 * @returns {string} The cleaned HTML content
 */
function extractListItemContent(element) {
  const clone = element.cloneNode(true);

  // Remove the list marker spans (mso-list:Ignore)
  clone.querySelectorAll('[style*="mso-list:Ignore"]').forEach((el) => {
    el.remove();
  });

  // Remove conditional comments content
  // Word wraps markers in <!--[if !supportLists]-->...<!--[endif]-->
  let html = clone.innerHTML;

  // Remove IE conditional comments
  html = html.replace(/<!\[if !supportLists\]>[\s\S]*?<!\[endif\]>/gi, "");

  // Clean up any remaining empty spans and normalize whitespace
  const temp = document.createElement("div");
  temp.innerHTML = html;

  // Remove empty elements
  temp.querySelectorAll("span, o\\:p").forEach((el) => {
    if (!el.textContent.trim() && !el.querySelector("img")) {
      el.remove();
    }
  });

  return temp.innerHTML.trim();
}

/**
 * Transforms Word list paragraphs into proper HTML list structure.
 * This function processes the DOM in place.
 *
 * @param {Document|Element} container - The container to process
 */
export function transformWordLists(container) {
  const paragraphs = Array.from(
    container.querySelectorAll(MSO_LIST_CLASSES.map((c) => `p.${c}`).join(", "))
  );

  if (paragraphs.length === 0) {
    return;
  }

  let currentList = null;
  let listStack = []; // Stack of {list, level, isOrdered} for nesting
  let lastLevel = 0;
  let currentListIsOrdered = false;

  paragraphs.forEach((p) => {
    const level = extractListLevel(p);
    // Detect list type BEFORE extracting content (which removes the markers)
    const listTypeInfo = detectListType(p);
    const content = extractListItemContent(p);
    const isFirst = p.className.includes("MsoListParagraphCxSpFirst");
    const isLast = p.className.includes("MsoListParagraphCxSpLast");

    // Create list item
    const li = document.createElement("li");
    li.innerHTML = content;

    if (isFirst || !currentList) {
      // Start a new top-level list, using detected type
      const listTag = listTypeInfo.isOrdered ? "ol" : "ul";
      currentList = document.createElement(listTag);
      currentList.setAttribute("data-tight", "true");
      if (listTypeInfo.isOrdered && listTypeInfo.startNumber !== 1) {
        currentList.setAttribute("start", String(listTypeInfo.startNumber));
      }
      currentListIsOrdered = listTypeInfo.isOrdered;
      listStack = [
        { list: currentList, level: 1, isOrdered: currentListIsOrdered },
      ];
      lastLevel = 1;

      // Insert the new list before this paragraph
      p.parentNode.insertBefore(currentList, p);
    }

    // Handle nesting
    if (level > lastLevel) {
      // Need to nest deeper - detect type for nested list from current item
      for (let i = lastLevel; i < level; i++) {
        const nestedListTag = listTypeInfo.isOrdered ? "ol" : "ul";
        const nestedList = document.createElement(nestedListTag);
        nestedList.setAttribute("data-tight", "true");
        if (listTypeInfo.isOrdered && listTypeInfo.startNumber !== 1) {
          nestedList.setAttribute("start", String(listTypeInfo.startNumber));
        }
        const parentList = listStack[listStack.length - 1].list;
        const lastItem = parentList.lastElementChild;

        if (lastItem) {
          lastItem.appendChild(nestedList);
        } else {
          parentList.appendChild(nestedList);
        }

        listStack.push({
          list: nestedList,
          level: i + 1,
          isOrdered: listTypeInfo.isOrdered,
        });
      }
    } else if (level < lastLevel) {
      // Need to go back up
      while (
        listStack.length > 1 &&
        listStack[listStack.length - 1].level > level
      ) {
        listStack.pop();
      }
    }

    // Add the item to the current level's list
    const targetList = listStack[listStack.length - 1].list;
    targetList.appendChild(li);

    lastLevel = level;

    // Remove the original paragraph
    p.remove();

    // If this is the last item, reset for potential next list
    if (isLast) {
      currentList = null;
      listStack = [];
      lastLevel = 0;
      currentListIsOrdered = false;
    }
  });
}

/**
 * Transforms Word list HTML string into standard HTML list structure.
 *
 * @param {string} html - The HTML string to transform
 * @returns {string} The transformed HTML
 */
export function transformWordListsHtml(html) {
  // Quick check if there's any Word list content
  if (!MSO_LIST_CLASSES.some((cls) => html.includes(cls))) {
    return html;
  }

  const doc = new DOMParser().parseFromString(html, "text/html");
  transformWordLists(doc.body);
  return doc.body.innerHTML;
}

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  plugins({ pmState: { Plugin } }) {
    return new Plugin({
      props: {
        transformPastedHTML(html) {
          return transformWordListsHtml(html);
        },
      },
    });
  },
};

export default extension;
