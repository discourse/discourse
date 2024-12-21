import {
  applyCachedInlineOnebox,
  cachedInlineOnebox,
} from "pretty-text/inline-oneboxer";
import { addToLoadingQueue, loadNext } from "pretty-text/oneboxer";
import { lookupCache } from "pretty-text/oneboxer-cache";
import { ajax } from "discourse/lib/ajax";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";
import escapeRegExp from "discourse-common/utils/escape-regexp";

export default {
  nodeSpec: {
    onebox: {
      attrs: { url: {}, html: {} },
      selectable: true,
      group: "block",
      atom: true,
      draggable: true,
      parseDOM: [
        {
          tag: "div.d-editor__onebox-wrapper",
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
        dom.classList.add("d-editor__onebox-wrapper");
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

  plugins: ({
    Plugin,
    ReplaceAroundStep,
    ReplaceStep,
    AddMarkStep,
    RemoveMarkStep,
    NodeSelection,
    utils,
  }) => {
    const plugin = new Plugin({
      appendTransaction(transactions, prevState, state) {
        const tr = state.tr;

        for (const transaction of transactions) {
          const replaceSteps = transaction.steps.filter(
            (step) => step instanceof ReplaceStep
          );

          for (const [index, step] of replaceSteps.entries()) {
            const map = transaction.mapping.maps[index];
            const [start, oldSize, newSize] = map.ranges;

            // if any onebox_inline moved position to be close to a text node
          }
        }

        // Return the transaction if any changes were made
        return tr.docChanged ? tr : null;
      },
      state: {
        init() {
          return { full: {}, inline: {} };
        },
        apply(tr, value) {
          const updated = { full: [], inline: [] };

          // we shouldn't check all descendants, but only the ones that have changed
          // it's a problem in other plugins too where we need to optimize
          tr.doc.descendants((node, pos) => {
            // if node has the link mark
            const link = node.marks.find((mark) => mark.type.name === "link");
            if (
              !tr.getMeta("autolinking") &&
              !link?.attrs.autoLink &&
              link?.attrs.href === node.textContent
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

              const obj = isInline ? updated.inline : updated.full;

              obj[node.textContent] ??= [];
              obj[node.textContent].push({
                pos,
                addToHistory: tr.getMeta("addToHistory"),
              });
            }
          });

          return updated;
        },
      },

      view() {
        return {
          async update(view, prevState) {
            if (prevState.doc.eq(view.state.doc)) {
              return;
            }

            const { full, inline } = plugin.getState(view.state);

            for (const [url, list] of Object.entries(full)) {
              const html = await loadFullOnebox(url, view.props.getContext());

              // naive check that this is not a <a href="url">url</a> onebox response
              if (
                new RegExp(
                  `<a href=["']${escapeRegExp(url)}["'].*>${escapeRegExp(
                    url
                  )}</a>`
                ).test(html)
              ) {
                continue;
              }

              for (const { pos, addToHistory } of list.sort(
                (a, b) => b.pos - a.pos
              )) {
                const tr = view.state.tr;
                console.log("replacing", pos, url);
                const node = tr.doc.nodeAt(pos);
                tr.replaceWith(
                  pos - 1,
                  pos + node.nodeSize,
                  view.state.schema.nodes.onebox.create({ url, html })
                );
                tr.setMeta("addToHistory", addToHistory);
                view.dispatch(tr);
              }
            }

            const inlineOneboxes = await loadInlineOneboxes(
              Object.keys(inline),
              view.props.getContext()
            );

            const tr = view.state.tr;
            for (const [url, onebox] of Object.entries(inlineOneboxes)) {
              for (const { pos, addToHistory } of inline[url]) {
                const newPos = tr.mapping.map(pos);
                const node = tr.doc.nodeAt(newPos);
                tr.replaceWith(
                  newPos,
                  newPos + node.nodeSize,
                  view.state.schema.nodes.onebox_inline.create({
                    url,
                    title: onebox.title,
                  })
                );
                if (addToHistory !== undefined) {
                  tr.setMeta("addToHistory", addToHistory);
                }
              }
            }
            if (tr.docChanged) {
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
      allOneboxes[url] = cached;
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
    if (onebox.title) {
      applyCachedInlineOnebox(onebox.url, onebox);
      allOneboxes[onebox.url] = onebox;
    }
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
