const MSO_LIST_CLASSES = [
  "MsoListParagraphCxSpFirst",
  "MsoListParagraphCxSpMiddle",
  "MsoListParagraphCxSpLast",
];

// Word's built-in quote-like paragraph styles ("Quote", "Intense Quote",
// "Block Text"). Word has no semantic blockquote, so it emits styled paragraphs
// instead of <blockquote>. Bare indentation (margin-left) is intentionally not
// treated as a quote - it's too ambiguous to convert reliably.
//
// Desktop Word marks the style with a non-localized class (e.g. MsoQuote).
// Word for the web ("WAC") instead tags runs with data-ccp-parastyle set to the
// internal (English) style name, regardless of the document language - so these
// match reliably across locales.
const MSO_QUOTE_CLASSES = ["MsoQuote", "MsoIntenseQuote", "MsoBlockText"];
const WAC_QUOTE_STYLES = ["Quote", "Intense Quote", "Block Text"];
const WAC_QUOTE_SELECTOR = WAC_QUOTE_STYLES.map(
  (style) => `[data-ccp-parastyle="${style}"]`
).join(", ");

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
    // Roman numerals, including larger numerals (i., ii., L., C., D., M.)
    if (/^[ivxlcdmIVXLCDM]+[.)]/.test(markerText)) {
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
    if (/^[ivxlcdmIVXLCDM]+[.)]/.test(markerText)) {
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

function isQuoteParagraph(node) {
  if (node?.nodeType !== Node.ELEMENT_NODE || node.tagName !== "P") {
    return false;
  }

  return (
    MSO_QUOTE_CLASSES.some((cls) => node.classList.contains(cls)) ||
    node.querySelector(WAC_QUOTE_SELECTOR) !== null
  );
}

function nextElementSibling(node) {
  let sibling = node.nextSibling;
  while (sibling && sibling.nodeType !== Node.ELEMENT_NODE) {
    sibling = sibling.nextSibling;
  }
  return sibling;
}

/**
 * Transforms Word quote-style paragraphs into <blockquote> elements, for both
 * desktop Word (class-based) and Word for the web (data-ccp-parastyle).
 * Consecutive quote paragraphs are merged into a single blockquote. This
 * function processes the DOM in place.
 *
 * @param {Document|Element} container - The container to process
 */
export function transformWordQuotes(container) {
  const candidates = new Set();

  // Desktop Word: quote style is a class on the paragraph
  container
    .querySelectorAll(MSO_QUOTE_CLASSES.map((c) => `p.${c}`).join(", "))
    .forEach((p) => candidates.add(p));

  // Word for the web: quote style is on a run inside the paragraph
  container.querySelectorAll(WAC_QUOTE_SELECTOR).forEach((run) => {
    const p = run.closest("p");
    if (p) {
      candidates.add(p);
    }
  });

  if (candidates.size === 0) {
    return;
  }

  // Walk paragraphs in document order so consecutive-sibling merging is stable
  const paragraphs = Array.from(container.querySelectorAll("p")).filter((p) =>
    candidates.has(p)
  );

  const absorbed = new Set();

  paragraphs.forEach((paragraph) => {
    if (absorbed.has(paragraph)) {
      return;
    }

    const blockquote = document.createElement("blockquote");
    paragraph.parentNode.insertBefore(blockquote, paragraph);

    // Merge this paragraph and any consecutive quote paragraphs into one
    // blockquote, preserving each as a paragraph with its inline formatting.
    let current = paragraph;
    while (isQuoteParagraph(current)) {
      const next = nextElementSibling(current);
      absorbed.add(current);
      current.classList.remove(...MSO_QUOTE_CLASSES);
      if (current.classList.length === 0) {
        current.removeAttribute("class");
      }
      blockquote.appendChild(current);
      current = next;
    }
  });
}

// Word review markup that should never make it into a post: comment reference
// anchors/markers, the comment body list Word appends at the end, and tracked
// deletions. Manual strikethrough is exported as <s>, not <del>, so dropping
// <del> only removes revision deletions.
const WORD_REVIEW_SELECTORS = [
  "a.msocomanchor",
  "span.MsoCommentReference",
  "[style*='mso-comment-reference']",
  "[style*='mso-special-character:comment']",
  "a[href^='#_msocom']",
  "a[name^='_msocom']",
  "hr.msocomoff",
  "[style*='mso-element:comment-list']",
  "[style*='mso-element:comment']",
  "p.MsoCommentText",
  "p.MsoCommentSubject",
  "del",
].join(", ");

// Word for the web has no mso-* markers; it uses these class names and
// data-ccp-* attributes. Anchored to class/attribute form so unrelated HTML
// that merely mentions the words isn't misread as Word.
const WAC_MARKERS =
  /class=["'][^"']*\b(?:OutlineElement|NormalTextRun|WACImageContainer)\b|data-ccp-[\w-]*=/;

/**
 * Detects whether an HTML string originated from Microsoft Word (desktop or
 * Word for the web), so that Word-only cleanup is not applied to other sources.
 *
 * @param {string} html - The HTML string to inspect
 * @returns {boolean}
 */
function isWordHtml(html) {
  return (
    html.includes("mso-") ||
    html.includes("urn:schemas-microsoft-com") ||
    /class=["']?Mso/.test(html) ||
    WAC_MARKERS.test(html)
  );
}

/**
 * Removes Word review markup (comments and tracked deletions) from a document.
 * This function processes the DOM in place.
 *
 * @param {Document|Element} container - The container to process
 */
export function stripWordReviewMarkup(container) {
  container
    .querySelectorAll(WORD_REVIEW_SELECTORS)
    .forEach((el) => el.remove());
}

// Word for the web stamps lang on every text span (<span class="TextRun" lang>),
// which the editor keeps and surfaces as literal <span lang> markup. Strip it
// from Word's own spans only, so a lang the user added on purpose survives.
const WORD_LANG_RUN_SELECTOR = "span[class*='TextRun'][lang]";

export function stripWordLangAttributes(container) {
  container
    .querySelectorAll(WORD_LANG_RUN_SELECTOR)
    .forEach((el) => el.removeAttribute("lang"));
}

/**
 * Transforms Word-specific markup in an HTML string into standard HTML:
 * converts Word lists and quote styles, and strips Word review markup
 * (comments and tracked deletions).
 *
 * @param {string} html - The HTML string to transform
 * @returns {string} The transformed HTML
 */
export function transformWordHtml(html) {
  const hasLists = MSO_LIST_CLASSES.some((cls) => html.includes(cls));
  const hasQuotes =
    MSO_QUOTE_CLASSES.some((cls) => html.includes(cls)) ||
    WAC_QUOTE_STYLES.some((style) =>
      html.includes(`data-ccp-parastyle="${style}"`)
    );
  const isWord = isWordHtml(html);

  // Quick check if there's any Word content we handle
  if (!hasLists && !hasQuotes && !isWord) {
    return html;
  }

  const doc = new DOMParser().parseFromString(html, "text/html");

  if (hasLists) {
    transformWordLists(doc.body);
  }

  if (hasQuotes) {
    transformWordQuotes(doc.body);
  }

  if (isWord) {
    stripWordReviewMarkup(doc.body);
    stripWordLangAttributes(doc.body);
  }

  return doc.body.innerHTML;
}

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  plugins({ pmState: { Plugin } }) {
    return new Plugin({
      props: {
        transformPastedHTML(html) {
          return transformWordHtml(html);
        },
      },
    });
  },
};

export default extension;
