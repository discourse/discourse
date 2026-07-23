import {
  applyInlineOneboxes,
  cachedInlineOnebox,
} from "pretty-text/inline-oneboxer";
import { load } from "pretty-text/oneboxer";
import { PluginKey, Selection } from "prosemirror-state";
import { ajax } from "discourse/lib/ajax";
import escapeRegExp from "discourse/lib/escape-regexp";
import {
  getLinkify,
  isWhiteSpace,
} from "discourse/static/prosemirror/lib/markdown-it";
import { i18n } from "discourse-i18n";
import { isTopLevel } from "discourse-markdown-it/features/onebox";

export const oneboxPluginKey = new PluginKey("onebox");

/**
 * Returns "full" if the link at `pos` is alone on its line at the document
 * root (renders as a block preview), "inline" otherwise (title-only preview).
 */
export function oneboxTypeAtPos(doc, pos) {
  const $pos = doc.resolve(pos);
  const parent = $pos.parent;
  const index = $pos.index();
  const prev = index > 0 ? parent.child(index - 1) : null;
  const next = index < parent.childCount - 1 ? parent.child(index + 1) : null;
  const isAlone =
    (!prev || prev.type.name === "hard_break") &&
    (!next ||
      next.type.name === "hard_break" ||
      hasTrailingWhitespaceOnly(doc, pos));
  return $pos.depth === 1 && isAlone ? "full" : "inline";
}

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    onebox: {
      attrs: { url: {}, html: {} },
      selectable: true,
      group: "block",
      draggable: true,
      parseDOM: [
        {
          tag: "div.onebox-wrapper",
          getAttrs(dom) {
            return { url: dom.dataset.oneboxSrc, html: dom.innerHTML };
          },
        },
        {
          tag: "aside.onebox",
          getAttrs(dom) {
            return { url: dom.dataset.oneboxSrc, html: dom.outerHTML };
          },
        },
      ],
      toDOM(node) {
        const dom = document.createElement("div");
        dom.dataset.oneboxSrc = node.attrs.url;
        dom.classList.add("onebox-wrapper");
        dom.innerHTML = node.attrs.html;
        return dom;
      },
    },
    onebox_inline: {
      attrs: { url: {}, title: {} },
      inline: true,
      group: "inline",
      selectable: true,
      draggable: true,
      parseDOM: [
        {
          tag: "a.inline-onebox",
          getAttrs(dom) {
            return { url: dom.getAttribute("href"), title: dom.textContent };
          },
          priority: 60,
        },
      ],
      toDOM(node) {
        return [
          "a",
          {
            class: "inline-onebox",
            href: node.attrs.url,
            contentEditable: true,
          },
          node.attrs.title,
        ];
      },
    },
  },
  serializeNode: {
    onebox(state, node) {
      state.ensureNewLine();
      state.write(`${node.attrs.url}\n\n`);
    },
    onebox_inline(state, node, parent, index) {
      if (!isWhiteSpace(state.out, state.out.length - 1)) {
        state.write(" ");
      }

      state.text(node.attrs.url);

      const nextSibling =
        parent.childCount > index + 1 ? parent.child(index + 1) : null;
      if (nextSibling?.isText && !isWhiteSpace(nextSibling.text, 0)) {
        state.write(" ");
      }
    },
  },

  plugins({
    pmState: { Plugin },
    pmView: { Decoration, DecorationSet },
    pmHistory: { isHistoryTransaction },
    getContext,
  }) {
    const failedUrls = { full: new Set(), inline: new Set() };

    // Scans for linkified URLs and creates onebox loading decorations.
    // `forceUrl` bypasses selection/topLevel/failed checks for that URL.
    function scanForOneboxLinks(doc, decoSet, tr, forceUrl) {
      const decorations = [];
      doc.descendants((node, pos) => {
        const link = node.marks.find((mark) => mark.type.name === "link");

        if (
          link?.attrs.markup === "linkify" &&
          getLinkify().test(node.text) &&
          decoSet.find(pos, pos + node.nodeSize).length === 0
        ) {
          const isForced = forceUrl === link.attrs.href;

          if (!isForced && !isOutsideSelection(pos, node.nodeSize, tr)) {
            return;
          }

          let oneboxType = oneboxTypeAtPos(doc, pos);

          // Hold a trailing-whitespace link inline while the cursor is on its
          // line, so the user can keep typing; appendTransaction promotes it.
          if (
            !isForced &&
            oneboxType === "full" &&
            hasTrailingWhitespaceOnly(doc, pos) &&
            selectionInSameBlock(doc, pos, tr.selection)
          ) {
            oneboxType = "inline";
          }

          if (
            !isForced &&
            isTopLevel(link.attrs.href) &&
            oneboxType === "inline"
          ) {
            return;
          }

          if (!isForced && failedUrls[oneboxType].has(link.attrs.href)) {
            return;
          }

          decorations.push(
            Decoration.inline(
              pos,
              pos + node.nodeSize,
              { class: "onebox-loading", nodeName: "span" },
              {
                oneboxUrl: link.attrs.href,
                oneboxType,
                forceRetry: isForced,
              }
            )
          );
        }
      });
      return decorations;
    }

    const plugin = new Plugin({
      key: oneboxPluginKey,
      state: {
        init() {
          return DecorationSet.empty;
        },
        apply(tr, set) {
          const meta = tr.getMeta(plugin);

          if (meta?.removeDecorations) {
            set = set.remove(meta.removeDecorations);
          }

          set = set.map(tr.mapping, tr.doc);

          if (!tr.docChanged) {
            if (meta?.inlineOneboxes) {
              const decosToUpdate = set.find(
                undefined,
                undefined,
                (spec) =>
                  spec.oneboxType === "inline" &&
                  spec.oneboxUrl &&
                  meta.inlineOneboxes.hasOwnProperty(spec.oneboxUrl)
              );

              const newDecorations = decosToUpdate.map((decoration) =>
                Decoration.inline(
                  decoration.from,
                  decoration.to,
                  { class: "onebox-loading", nodeName: "span" },
                  {
                    oneboxUrl: decoration.spec.oneboxUrl,
                    oneboxType: decoration.spec.oneboxType,
                    oneboxTitle: meta.inlineOneboxes[decoration.spec.oneboxUrl],
                    oneboxDataLoaded: true,
                    forceRetry: decoration.spec.forceRetry,
                  }
                )
              );

              set = set.remove(decosToUpdate).add(tr.doc, newDecorations);
            }

            if (meta?.oneboxContent) {
              const { url, html } = meta.oneboxContent;

              const decosToUpdate = set.find(
                undefined,
                undefined,
                (spec) => spec.oneboxType === "full" && spec.oneboxUrl === url
              );

              const newDecorations = decosToUpdate.map((decoration) => {
                return Decoration.inline(
                  decoration.from,
                  decoration.to,
                  { class: "onebox-loading", nodeName: "span" },
                  {
                    oneboxUrl: decoration.spec.oneboxUrl,
                    oneboxType: decoration.spec.oneboxType,
                    oneboxDataLoaded: true,
                    oneboxHtml: html,
                  }
                );
              });

              set = set.remove(decosToUpdate).add(tr.doc, newDecorations);
            }

            if (!meta?.forceOneboxUrl) {
              return set;
            }
          }

          // Don't re-onebox a link an undo just peeled back from a preview, or
          // the promotion re-runs and undo can never move past it. Redo replays
          // the recorded preview, so skip history transactions entirely.
          if (!meta?.forceOneboxUrl && isHistoryTransaction(tr)) {
            return set;
          }

          const decorations = scanForOneboxLinks(
            tr.doc,
            set,
            tr,
            meta?.forceOneboxUrl
          );

          return set.add(tr.doc, decorations);
        },
      },

      props: {
        decorations(state) {
          return plugin.getState(state);
        },
      },

      view() {
        const pendingUrls = { inline: new Set(), full: new Set() };

        return {
          update(view) {
            const decorations = plugin.getState(view.state);

            this.processNew(view, decorations);
            this.processLoaded(view, decorations);
          },

          processNew(view, allDecorations) {
            const decorations = allDecorations.find(
              undefined,
              undefined,
              (spec) =>
                !spec.oneboxDataLoaded &&
                !pendingUrls[spec.oneboxType].has(spec.oneboxUrl)
            );

            for (const dec of decorations) {
              if (
                !dec.spec.forceRetry &&
                failedUrls[dec.spec.oneboxType].has(dec.spec.oneboxUrl)
              ) {
                continue;
              }

              pendingUrls[dec.spec.oneboxType].add(dec.spec.oneboxUrl);

              // Full onebox, one by one
              if (dec.spec.oneboxType === "full") {
                const { oneboxUrl, forceRetry } = dec.spec;

                if (forceRetry) {
                  failedUrls.full.delete(oneboxUrl);
                }

                processOnebox(oneboxUrl, getContext(), { refresh: forceRetry })
                  .then((html) => {
                    pendingUrls.full.delete(oneboxUrl);
                    if (html) {
                      view.dispatch(
                        view.state.tr.setMeta(plugin, {
                          oneboxContent: { url: oneboxUrl, html },
                        })
                      );
                    } else {
                      failedUrls.full.add(oneboxUrl);
                      if (forceRetry) {
                        showPreviewFailedToast();
                      }
                    }
                  })
                  .catch(() => {
                    pendingUrls.full.delete(oneboxUrl);
                    failedUrls.full.add(oneboxUrl);
                    if (forceRetry) {
                      showPreviewFailedToast();
                    }
                  });
              }
            }

            // Inline oneboxes, batched
            if (pendingUrls.inline.size) {
              const inlineUrls = pendingUrls.inline;
              loadInlineOneboxes(inlineUrls, getContext()).then(
                (inlineOneboxes) => {
                  for (const url of inlineUrls) {
                    pendingUrls.inline.delete(url);
                  }

                  if (Object.keys(inlineOneboxes).length > 0) {
                    view.dispatch(
                      view.state.tr.setMeta(plugin, { inlineOneboxes })
                    );
                  }
                }
              );
            }
          },

          processLoaded(view, allDecorations) {
            const decorations = allDecorations.find(
              undefined,
              undefined,
              (spec) => spec.oneboxDataLoaded
            );

            const removeDecorations = [];
            const sortedDecos = decorations.sort((a, b) => b.from - a.from);
            const tr = view.state.tr;

            for (const decoration of sortedDecos) {
              const nodeAtPos = view.state.doc.nodeAt(decoration.from);

              const isTextNode = nodeAtPos?.isText;

              const matchingLink = nodeAtPos?.marks.find(
                (mark) =>
                  mark.type.name === "link" &&
                  mark.attrs.href === decoration.spec.oneboxUrl
              );

              if (!isTextNode || !matchingLink) {
                continue;
              }

              if (decoration.spec.oneboxType === "inline") {
                if (decoration.spec.oneboxTitle) {
                  const oneboxNode =
                    view.state.schema.nodes.onebox_inline.create({
                      url: nodeAtPos.text,
                      title: decoration.spec.oneboxTitle,
                    });

                  tr.replaceWith(decoration.from, decoration.to, oneboxNode);
                } else {
                  failedUrls.inline.add(decoration.spec.oneboxUrl);
                  if (decoration.spec.forceRetry) {
                    showPreviewFailedToast();
                  }
                }
              } else if (decoration.spec.oneboxType === "full") {
                if (decoration.spec.oneboxHtml) {
                  const oneboxNode = view.state.schema.nodes.onebox.create({
                    url: nodeAtPos.text,
                    html: decoration.spec.oneboxHtml,
                  });

                  const $pos = view.state.doc.resolve(decoration.from);
                  if ($pos.parent.type.name === "paragraph") {
                    const from = $pos.before();
                    const to = $pos.after();
                    const cursorOnLine =
                      view.state.selection.from >= from &&
                      view.state.selection.to <= to;
                    const nodes = splitParagraphAroundOnebox($pos, oneboxNode);

                    // Give the cursor somewhere to land after the onebox when it
                    // would otherwise end the document, so it isn't left
                    // selecting the block (where typing would replace it).
                    if (
                      nodes[nodes.length - 1] === oneboxNode &&
                      to === view.state.doc.content.size
                    ) {
                      nodes.push(view.state.schema.nodes.paragraph.create());
                    }

                    tr.replaceWith(from, to, nodes);

                    if (cursorOnLine) {
                      const afterOnebox =
                        from +
                        (nodes[0] === oneboxNode ? 0 : nodes[0].nodeSize) +
                        oneboxNode.nodeSize;
                      tr.setSelection(
                        Selection.near(tr.doc.resolve(afterOnebox), 1)
                      );
                    }
                  } else {
                    tr.replaceWith(decoration.from, decoration.to, oneboxNode);
                  }
                } else {
                  failedUrls.full.add(decoration.spec.oneboxUrl);
                }
              }

              removeDecorations.push(decoration);
            }

            if (removeDecorations.length || tr.docChanged) {
              tr.setMeta(plugin, { removeDecorations });
              view.dispatch(tr);
            }
          },
        };
      },

      // Promote an inline onebox to a full preview once it ends up alone on its
      // line (e.g. after Enter, or surrounding text is removed), matching how it
      // cooks. Resets it to a link so scanForOneboxLinks reuses the fetch path.
      appendTransaction(transactions, prevState, state) {
        const docChanged = transactions.some((tr) => tr.docChanged);
        const selectionChanged = !prevState.selection.eq(state.selection);

        if (!docChanged && !selectionChanged) {
          return;
        }

        // Re-check the block the cursor just left, mapped to the near side of
        // any split so it lands in the paragraph left behind (e.g. by Enter).
        let leftPos = prevState.selection.from;
        for (const tr of transactions) {
          leftPos = tr.mapping.map(leftPos, -1);
        }

        const tr = state.tr;
        const inspected = new Set();

        for (const position of [state.selection.from, leftPos]) {
          const { from, to } = topBlockRange(state.doc, position);
          if (inspected.has(from)) {
            continue;
          }
          inspected.add(from);

          state.doc.nodesBetween(from, to, (node, nodePos) => {
            if (node.type.name !== "onebox_inline") {
              return;
            }

            if (oneboxTypeAtPos(state.doc, nodePos) !== "full") {
              return;
            }

            if (selectionInSameBlock(state.doc, nodePos, state.selection)) {
              return;
            }

            const { url } = node.attrs;
            const mark = state.schema.marks.link.create({
              href: url,
              markup: "linkify",
            });

            tr.replaceWith(
              tr.mapping.map(nodePos),
              tr.mapping.map(nodePos + node.nodeSize),
              state.schema.text(url, [mark])
            );
          });
        }

        return tr.steps.length ? tr.setMeta("addToHistory", false) : null;
      },
    });

    function showPreviewFailedToast() {
      getContext().toasts.default({
        duration: "short",
        data: {
          message: i18n("composer.link_toolbar.preview_failed"),
        },
      });
    }

    return plugin;
  },
};

// True when the link at `pos` is followed only by a single whitespace-only text
// node (a trailing space the markdown parser trims, so it still cooks to full).
function hasTrailingWhitespaceOnly(doc, pos) {
  const $pos = doc.resolve(pos);
  const parent = $pos.parent;
  const index = $pos.index();

  if (index !== parent.childCount - 2) {
    return false;
  }

  const next = parent.child(index + 1);
  return next.isText && [...next.text].every((char) => isWhiteSpace(char));
}

// A full onebox is a block node, so it can't stay inside the paragraph. The link
// can still share its paragraph with other lines via hard breaks (shift+enter),
// so split those lines into their own paragraphs around the onebox and drop the
// hard breaks (or trailing space) bounding the link.
function splitParagraphAroundOnebox($pos, oneboxNode) {
  const parent = $pos.parent;
  const index = $pos.index();
  const isHardBreak = (i) =>
    i >= 0 &&
    i < parent.childCount &&
    parent.child(i).type.name === "hard_break";
  const childrenBetween = (from, to) => {
    const children = [];
    for (let i = from; i < to; i++) {
      children.push(parent.child(i));
    }
    return children;
  };

  const nodes = [];

  if (isHardBreak(index - 1)) {
    const before = childrenBetween(0, index - 1);
    if (before.length) {
      nodes.push(parent.type.create(parent.attrs, before));
    }
  }

  nodes.push(oneboxNode);

  if (isHardBreak(index + 1)) {
    const after = childrenBetween(index + 2, parent.childCount);
    if (after.length) {
      nodes.push(parent.type.create(parent.attrs, after));
    }
  }

  return nodes;
}

function topBlockRange(doc, pos) {
  const clamped = Math.max(0, Math.min(pos, doc.content.size));
  const $pos = doc.resolve(clamped);

  if ($pos.depth === 0) {
    const after = $pos.nodeAfter;
    if (after) {
      return { from: clamped, to: clamped + after.nodeSize };
    }
    const before = $pos.nodeBefore;
    if (before) {
      return { from: clamped - before.nodeSize, to: clamped };
    }
    return { from: clamped, to: clamped };
  }

  return { from: $pos.before(1), to: $pos.after(1) };
}

function selectionInSameBlock(doc, pos, selection) {
  const { from, to } = topBlockRange(doc, pos);
  return selection.from >= from && selection.to <= to;
}

function isOutsideSelection(from, to, tr) {
  const { selection, doc } = tr;

  const nodeEnd = from + to;

  if (selection.from <= nodeEnd && selection.to >= from) {
    return false;
  }

  const text = doc.textBetween(
    selection.to < from ? selection.to : nodeEnd,
    selection.to < from ? from : selection.from,
    " ",
    " "
  );

  for (let i = 0; i < text.length; i++) {
    if (isWhiteSpace(text[i])) {
      return true;
    }
  }

  return false;
}

// Dummy element to pass to the oneboxer
// To avoid this, we need to refactor both oneboxer APIs
const dummyElement = {
  replaceWith() {},
  classList: { remove() {}, add() {}, contains: () => false },
  dataset: {},
};

async function loadInlineOneboxes(urls, { categoryId, topicId }) {
  const oneboxes = {};
  const elems = {};

  for (const url of urls) {
    const cached = cachedInlineOnebox(url);
    if (cached) {
      oneboxes[url] = cached.title;
    } else {
      elems[url] = [{ ...dummyElement }];
    }
  }

  await applyInlineOneboxes(elems, ajax, { categoryId, topicId });

  for (const [url, [onebox]] of Object.entries(elems)) {
    oneboxes[url] = onebox.innerText;
  }

  return oneboxes;
}

async function processOnebox(href, { topicId, categoryId }, opts = {}) {
  const html = await new Promise((onResolve) => {
    load({
      topicId,
      categoryId,
      elem: { ...dummyElement, href },
      onResolve,
      ajax,
      refresh: opts.refresh ?? false,
    });
  });

  // Not a <a href="url">url</a> onebox response
  if (
    new RegExp(
      `^<a href=["']${escapeRegExp(href)}["'].*>${escapeRegExp(href)}</a>$`
    ).test(html)
  ) {
    return;
  }

  return html;
}

export default extension;
