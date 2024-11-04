import { cachedInlineOnebox } from "pretty-text/inline-oneboxer";
import { lookupCache } from "pretty-text/oneboxer-cache";

export default {
  nodeSpec: {
    onebox: {
      attrs: { url: {}, html: {} },
      selectable: false,
      group: "inline",
      inline: true,
      atom: true,
      draggable: true,
      parseDOM: [
        {
          tag: "aside.onebox",
          getAttrs(dom) {
            return { url: dom["data-onebox-src"], html: dom.outerHTML };
          },
        },
      ],
      toDOM(node) {
        // const dom = document.createElement("aside");
        // dom.outerHTML = node.attrs.html;

        // TODO(renato): revisit?
        return new DOMParser().parseFromString(node.attrs.html, "text/html")
          .body.firstChild;
      },
    },
  },
  serializeNode: {
    onebox(state, node) {
      state.write(node.attrs.url);
    },
  },

  plugins: ({ Plugin }) => {
    const plugin = new Plugin({
      state: {
        init() {
          return [];
        },
        apply(tr, value) {
          // TODO(renato)
          return value;
        },
      },

      view() {
        return {
          update(view, prevState) {
            if (prevState.doc.eq(view.state.doc)) {
              return;
            }

            // console.log("discourse", view.props.discourse);

            const unresolvedLinks = plugin.getState(view.state);

            // console.log(unresolvedLinks);

            for (const unresolved of unresolvedLinks) {
              const isInline = unresolved.isInline;
              // console.log(isInline, cachedInlineOnebox(unresolved.text));

              const className = isInline
                ? "onebox-loading"
                : "inline-onebox-loading";

              if (!isInline) {
                // console.log(lookupCache(unresolved.text));
              }
            }
          },
        };
      },
    });

    return plugin;
  },
};

function isValidUrl(text) {
  try {
    new URL(text); // If it can be parsed as a URL, it's valid.
    return true;
  } catch {
    return false;
  }
}

function isNodeInline(state, pos) {
  const resolvedPos = state.doc.resolve(pos);
  const parent = resolvedPos.parent;

  return parent.childCount !== 1;
}
