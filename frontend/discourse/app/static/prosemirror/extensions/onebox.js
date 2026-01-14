import {
  applyInlineOneboxes,
  cachedInlineOnebox,
} from "pretty-text/inline-oneboxer";
import { load } from "pretty-text/oneboxer";
import { ajax } from "discourse/lib/ajax";
import escapeRegExp from "discourse/lib/escape-regexp";
import { isWhiteSpace } from "discourse/static/prosemirror/lib/markdown-it";
import { isTopLevel } from "discourse-markdown-it/features/onebox";

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
    getContext,
  }) {
    const failedUrls = { full: new Set(), inline: new Set() };

    const plugin = new Plugin({
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

            return set;
          }

          const decorations = [];
          tr.doc.descendants((node, pos) => {
            const link = node.marks.find((mark) => mark.type.name === "link");

            if (
              link?.attrs.markup === "linkify" &&
              set.find(pos, pos + node.nodeSize).length === 0 &&
              isOutsideSelection(pos, node.nodeSize, tr)
            ) {
              const resolvedPos = tr.doc.resolve(pos);
              const isAtRoot = resolvedPos.depth === 1;
              const parent = resolvedPos.parent;
              const index = resolvedPos.index();
              const prev = index > 0 ? parent.child(index - 1) : null;
              const next =
                index < parent.childCount - 1 ? parent.child(index + 1) : null;
              const isAlone =
                (!prev || prev.type.name === "hard_break") &&
                (!next || next.type.name === "hard_break");
              const isInline = !isAtRoot || !isAlone;

              const oneboxType = isInline ? "inline" : "full";

              // inline oneboxes should not be created for top-level links
              if (isTopLevel(link.attrs.href) && isInline) {
                return;
              }

              if (failedUrls[oneboxType].has(link.attrs.href)) {
                return;
              }

              decorations.push(
                Decoration.inline(
                  pos,
                  pos + node.nodeSize,
                  { class: "onebox-loading", nodeName: "span" },
                  { oneboxUrl: link.attrs.href, oneboxType }
                )
              );
            }
          });

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
              if (failedUrls[dec.spec.oneboxType].has(dec.spec.oneboxUrl)) {
                continue;
              }

              pendingUrls[dec.spec.oneboxType].add(dec.spec.oneboxUrl);

              // Full onebox, one by one
              if (dec.spec.oneboxType === "full") {
                const { oneboxUrl } = dec.spec;
                pendingUrls.full.add(oneboxUrl);

                processOnebox(oneboxUrl, getContext()).then((html) => {
                  pendingUrls.full.delete(oneboxUrl);
                  if (html) {
                    view.dispatch(
                      view.state.tr.setMeta(plugin, {
                        oneboxContent: { url: oneboxUrl, html },
                      })
                    );
                  } else {
                    failedUrls.full.add(oneboxUrl);
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
                }
              } else if (decoration.spec.oneboxType === "full") {
                if (decoration.spec.oneboxHtml) {
                  const oneboxNode = view.state.schema.nodes.onebox.create({
                    url: nodeAtPos.text,
                    html: decoration.spec.oneboxHtml,
                  });

                  const $pos = view.state.doc.resolve(decoration.from);
                  const paragraph = $pos.parent;
                  if (
                    paragraph.type.name === "paragraph" &&
                    paragraph.childCount === 1
                  ) {
                    tr.replaceWith($pos.before(), $pos.after(), oneboxNode);
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
    });

    return plugin;
  },
};

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

async function processOnebox(href, { topicId, categoryId }) {
  const html = await new Promise((onResolve) => {
    load({
      topicId,
      categoryId,
      elem: { ...dummyElement, href },
      onResolve,
      ajax,
      refresh: false,
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
