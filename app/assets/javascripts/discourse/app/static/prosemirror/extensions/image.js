import {
  lookupCachedUploadUrl,
  lookupUncachedUploadUrls,
} from "pretty-text/upload-short-url";
import { ajax } from "discourse/lib/ajax";
import { isNumeric } from "discourse/lib/utilities";

const PLACEHOLDER_IMG = "/images/transparent.png";

const ALT_TEXT_REGEX =
  /^(.*?)(?:\|(\d{1,4}x\d{1,4}))?(?:,\s*(\d{1,3})%)?(?:\|(.*))?$/;

export default {
  nodeSpec: {
    image: {
      inline: true,
      attrs: {
        src: {},
        alt: { default: null },
        title: { default: null },
        // Overriding ProseMirror's default node to support these attrs
        width: { default: null },
        height: { default: null },
        "data-orig-src": { default: null },
        "data-thumbnail": { default: false },
        "data-scale": { default: null },
        "data-placeholder": { default: null },
      },
      group: "inline",
      draggable: true,
      parseDOM: [
        {
          tag: "img[src]",
          getAttrs(dom) {
            return {
              src: dom.getAttribute("src"),
              title: dom.getAttribute("title"),
              alt: dom.getAttribute("alt"),
              width: dom.getAttribute("width"),
              height: dom.getAttribute("height"),
              "data-orig-src": dom.getAttribute("data-orig-src"),
              "data-thumbnail": dom.hasAttribute("data-thumbnail"),
            };
          },
        },
      ],
      toDOM(node) {
        const width = node.attrs.width
          ? (node.attrs.width * (node.attrs["data-scale"] || 100)) / 100
          : undefined;
        const height = node.attrs.height
          ? (node.attrs.height * (node.attrs["data-scale"] || 100)) / 100
          : undefined;

        return ["img", { ...node.attrs, width, height }];
      },
    },
  },

  parse: {
    image: {
      node: "image",
      getAttrs(token) {
        const [, altText, dimensions, percent, extras] =
          token.content.match(ALT_TEXT_REGEX);

        const [width, height] = dimensions?.split("x") ?? [];

        return {
          src: token.attrGet("src"),
          title: token.attrGet("title"),
          alt: altText,
          "data-orig-src": token.attrGet("data-orig-src"),
          width,
          height,
          "data-scale":
            percent && isNumeric(percent) ? parseInt(percent, 10) : undefined,
          "data-thumbnail": extras === "thumbnail",
        };
      },
    },
  },

  serializeNode: {
    image(state, node) {
      if (node.attrs["data-placeholder"]) {
        return;
      }

      const alt = (node.attrs.alt || "").replace(/([\\[\]`])/g, "\\$1");
      const scale = node.attrs["data-scale"]
        ? `, ${node.attrs["data-scale"]}%`
        : "";
      const dimensions =
        node.attrs.width && node.attrs.height
          ? `|${node.attrs.width}x${node.attrs.height}${scale}`
          : "";
      const thumbnail = node.attrs["data-thumbnail"] ? "|thumbnail" : "";
      const src = node.attrs["data-orig-src"] ?? node.attrs.src ?? "";
      const escapedSrc = src.replace(/[\(\)]/g, "\\$&");
      const title = node.attrs.title
        ? ' "' + node.attrs.title.replace(/"/g, '\\"') + '"'
        : "";

      state.write(`![${alt}${dimensions}${thumbnail}](${escapedSrc}${title})`);
    },
  },

  plugins: ({ Plugin }) => {
    const shortUrlResolver = new Plugin({
      state: {
        init() {
          return [];
        },
        apply(tr, value) {
          let updated = value.slice();

          tr.doc.descendants((node, pos) => {
            if (node.type.name === "image" && node.attrs["data-orig-src"]) {
              if (node.attrs.src === PLACEHOLDER_IMG) {
                updated.push({ pos, src: node.attrs["data-orig-src"] });
              } else {
                updated = updated.filter(
                  (u) => u.src !== node.attrs["data-orig-src"]
                );
              }
            }
          });

          return updated;
        },
      },

      view() {
        return {
          update: async (view, prevState) => {
            if (prevState.doc.eq(view.state.doc)) {
              return;
            }

            const unresolvedUrls = shortUrlResolver.getState(view.state);

            // Process only unresolved URLs
            for (const unresolved of unresolvedUrls) {
              const cachedUrl = lookupCachedUploadUrl(unresolved.src).url;
              const url =
                cachedUrl ||
                (await lookupUncachedUploadUrls([unresolved.src], ajax))[0]
                  ?.url;

              if (url) {
                const node = view.state.doc.nodeAt(unresolved.pos);
                if (node) {
                  const attrs = { ...node.attrs, src: url };
                  const transaction = view.state.tr
                    .setNodeMarkup(unresolved.pos, null, attrs)
                    .setMeta("addToHistory", false);

                  view.dispatch(transaction);
                }
              }
            }
          },
        };
      },
    });

    return shortUrlResolver;
  },
};
