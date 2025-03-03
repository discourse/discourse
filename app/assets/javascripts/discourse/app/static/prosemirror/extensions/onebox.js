import {
  applyCachedInlineOnebox,
  cachedInlineOnebox,
} from "pretty-text/inline-oneboxer";
import { addToLoadingQueue, loadNext } from "pretty-text/oneboxer";
import { lookupCache } from "pretty-text/oneboxer-cache";
import { ajax } from "discourse/lib/ajax";
import escapeRegExp from "discourse/lib/escape-regexp";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    onebox: {
      attrs: { url: {}, html: {} },
      selectable: true,
      group: "block",
      atom: true,
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
      atom: true,
      draggable: true,
      parseDOM: [
        {
          // TODO link marks are still processed before this when pasting
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
            contentEditable: false,
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
      if (!isBoundary(state.out, state.out.length - 1)) {
        state.write(" ");
      }

      state.text(node.attrs.url);

      const nextSibling =
        parent.childCount > index + 1 ? parent.child(index + 1) : null;
      // TODO(renato): differently from emoji/hashtag, some few punct chars
      //  we don't want to join, like -#%/:@
      if (nextSibling?.isText && !isBoundary(nextSibling.text, 0)) {
        state.write(" ");
      }
    },
  },

  plugins({
    pmState: { Plugin },
    pmView: { Decoration, DecorationSet },
    getContext,
  }) {
    let updatedView;
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
            const inlineOneboxes = meta?.loadInlineOneboxes;
            if (inlineOneboxes) {
              const decosToUpdate = set.find(
                undefined,
                undefined,
                (spec) =>
                  spec.oneboxType === "inline" &&
                  spec.oneboxUrl &&
                  inlineOneboxes.hasOwnProperty(spec.oneboxUrl)
              );

              const newDecorations = decosToUpdate.map((dec) =>
                Decoration.inline(
                  dec.from,
                  dec.to,
                  { class: "onebox-loading", nodeName: "span" },
                  {
                    oneboxUrl: dec.spec.oneboxUrl,
                    oneboxType: dec.spec.oneboxType,
                    oneboxTitle: inlineOneboxes[dec.spec.oneboxUrl],
                    oneboxDataLoaded: true,
                    inclusiveStart: true,
                    inclusiveEnd: true,
                  }
                )
              );

              set = set.remove(decosToUpdate).add(tr.doc, newDecorations);
            }

            const oneboxContent = meta?.loadOneboxContent;
            if (oneboxContent) {
              const { url, html } = oneboxContent;

              const decosToUpdate = set.find(
                undefined,
                undefined,
                (spec) => spec.oneboxType === "full" && spec.oneboxUrl === url
              );

              const newDecorations = decosToUpdate.map((dec) => {
                return Decoration.inline(
                  dec.from,
                  dec.to,
                  { class: "onebox-loading", nodeName: "span" },
                  {
                    oneboxUrl: dec.spec.oneboxUrl,
                    oneboxType: dec.spec.oneboxType,
                    oneboxDataLoaded: true,
                    oneboxHtml: html,
                    inclusiveStart: true,
                    inclusiveEnd: true,
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
              link?.attrs.href === node.textContent &&
              set.find(pos, pos + node.nodeSize).length === 0
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

              if (!failedUrls[oneboxType].has(node.textContent)) {
                decorations.push(
                  Decoration.inline(
                    pos,
                    pos + node.nodeSize,
                    { class: "onebox-loading", nodeName: "span" },
                    {
                      oneboxUrl: node.textContent,
                      oneboxType,
                      inclusiveStart: true,
                      inclusiveEnd: true,
                    }
                  )
                );

                if (!isInline) {
                  processOnebox(node.textContent, getContext()).then((html) => {
                    if (updatedView) {
                      updatedView.dispatch(
                        updatedView.state.tr.setMeta(plugin, {
                          loadOneboxContent: { url: node.textContent, html },
                        })
                      );
                    }
                  });
                }
              }
            }
          });

          const urlsToLoad = decorations
            .filter((dec) => dec.spec.oneboxType === "inline")
            .map((dec) => dec.spec.oneboxUrl);

          if (urlsToLoad.length) {
            loadInlineOneboxes(urlsToLoad, getContext()).then((allOneboxes) => {
              if (!Object.keys(allOneboxes).length || !updatedView) {
                return;
              }
              updatedView.dispatch(
                updatedView.state.tr.setMeta(plugin, {
                  loadInlineOneboxes: allOneboxes,
                })
              );
            });
          }

          return set.add(tr.doc, decorations);
        },
      },

      props: {
        decorations(state) {
          return plugin.getState(state);
        },
      },

      view() {
        return {
          update(view) {
            updatedView = view;

            const decorations = plugin.getState(view.state);

            const loadedDecos = decorations.find(
              undefined,
              undefined,
              (spec) => spec.oneboxDataLoaded
            );

            if (loadedDecos.length === 0) {
              return;
            }

            const tr = view.state.tr;
            const decosToRemove = [];

            const sortedDecos = [...loadedDecos].sort(
              (a, b) => b.from - a.from
            );

            for (const dec of sortedDecos) {
              if (
                dec.from >= view.state.doc.content.size ||
                dec.to > view.state.doc.content.size ||
                dec.from < 0
              ) {
                continue;
              }

              const nodeAtPos = view.state.doc.nodeAt(dec.from);

              if (!nodeAtPos || !nodeAtPos.isText || !nodeAtPos.marks?.length) {
                continue;
              }

              const linkMark = nodeAtPos.marks.find(
                (mark) =>
                  mark.type.name === "link" &&
                  mark.attrs.href === dec.spec.oneboxUrl
              );

              if (!linkMark) {
                continue;
              }

              const textEnd = dec.from + nodeAtPos.nodeSize;

              if (textEnd !== dec.to) {
                continue;
              }

              if (!dec.spec.oneboxDataLoaded) {
                continue;
              }

              if (dec.spec.oneboxType === "inline") {
                if (dec.spec.oneboxTitle) {
                  const oneboxNode =
                    view.state.schema.nodes.onebox_inline.create({
                      url: dec.spec.oneboxUrl,
                      title: dec.spec.oneboxTitle,
                    });

                  tr.replaceWith(dec.from, dec.to, oneboxNode);
                } else {
                  failedUrls.inline.add(dec.spec.oneboxUrl);
                }

                decosToRemove.push(dec);
              } else if (dec.spec.oneboxType === "full") {
                if (dec.spec.oneboxHtml) {
                  const oneboxNode = view.state.schema.nodes.onebox.create({
                    url: dec.spec.oneboxUrl,
                    html: dec.spec.oneboxHtml,
                  });

                  const $pos = view.state.doc.resolve(dec.from);
                  const paragraph = $pos.parent;
                  if (
                    paragraph.type.name === "paragraph" &&
                    paragraph.childCount === 1
                  ) {
                    tr.replaceWith($pos.before(), $pos.after(), oneboxNode);
                  } else {
                    tr.replaceWith(dec.from, dec.to, oneboxNode);
                  }
                } else {
                  failedUrls.full.add(dec.spec.oneboxUrl);
                }

                decosToRemove.push(dec);
              }
            }

            if (decosToRemove.length || tr.docChanged) {
              tr.setMeta(plugin, { removeDecorations: decosToRemove });
              view.dispatch(tr);
            }
          },
        };
      },
    });

    return plugin;
  },
};

async function loadInlineOneboxes(urls, { categoryId, topicId }) {
  const allOneboxes = {};

  const uncachedUrls = [];
  for (const url of urls) {
    const cached = cachedInlineOnebox(url);
    if (cached) {
      allOneboxes[url] = cached.title;
    } else {
      uncachedUrls.push(url);
    }
  }

  if (uncachedUrls.length === 0) {
    return allOneboxes;
  }

  const { "inline-oneboxes": oneboxes } = await ajax("/inline-onebox", {
    data: { urls: uncachedUrls, categoryId, topicId },
  });

  oneboxes.forEach((onebox) => {
    applyCachedInlineOnebox(onebox.url, onebox);
    allOneboxes[onebox.url] = onebox.title;
  });

  return allOneboxes;
}

async function loadFullOnebox(url, { categoryId, topicId }) {
  const cached = lookupCache(url);
  if (cached) {
    return cached;
  }

  return new Promise((onResolve) => {
    addToLoadingQueue({ url, categoryId, topicId, onResolve });
    loadNext(ajax);
  });
}

async function processOnebox(url, context) {
  const html = await loadFullOnebox(url, context);

  // naive check that this is not a <a href="url">url</a> onebox response
  if (
    new RegExp(
      `<a href=["']${escapeRegExp(url)}["'].*>${escapeRegExp(url)}</a>`
    ).test(html)
  ) {
    return;
  }

  return html;
}

export default extension;
