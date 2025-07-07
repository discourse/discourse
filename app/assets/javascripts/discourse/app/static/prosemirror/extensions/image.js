import {
  lookupCachedUploadUrl,
  lookupUncachedUploadUrls,
} from "pretty-text/upload-short-url";
import { ajax } from "discourse/lib/ajax";
import { isNumeric } from "discourse/lib/utilities";
import ImageNodeView from "../components/image-node-view";
import GlimmerNodeView from "../lib/glimmer-node-view";

const PLACEHOLDER_IMG = "/images/transparent.png";

const ALT_TEXT_REGEX =
  /^(.*?)(?:\|(\d{1,4}x\d{1,4}))?(?:,\s*(\d{1,3})%)?(?:\|(.*))?$/;

const createImageNodeView =
  ({ getContext }) =>
  (node, view, getPos) => {
    if (
      node.attrs.placeholder ||
      node.attrs.extras === "audio" ||
      node.attrs.extras === "video"
    ) {
      return null;
    }

    return new GlimmerNodeView({
      node,
      view,
      getPos,
      getContext,
      component: ImageNodeView,
      name: "image",
    });
  };

/** @type {RichEditorExtension} */
const extension = {
  nodeViews: { image: createImageNodeView },

  nodeSpec: {
    image: {
      inline: true,
      attrs: {
        src: { default: "" },
        alt: { default: null },
        title: { default: null },
        width: { default: null },
        height: { default: null },
        originalSrc: { default: null },
        extras: { default: null },
        scale: { default: null },
        placeholder: { default: null },
      },
      group: "inline",
      draggable: true,
      parseDOM: [
        {
          tag: "img[src]",
          getAttrs(dom) {
            const originalSrc =
              dom.dataset.origSrc ??
              (dom.dataset.base62Sha1
                ? `upload://${dom.dataset.base62Sha1}`
                : undefined);

            const extras = dom.hasAttribute("data-thumbnail")
              ? "thumbnail"
              : undefined;

            return {
              src: dom.getAttribute("src"),
              title: dom.getAttribute("title")?.replace(/\n/g, " "),
              alt: dom.getAttribute("alt")?.replace(/\n/g, " "),
              width: dom.getAttribute("width"),
              height: dom.getAttribute("height"),
              originalSrc,
              extras,
              scale: dom.getAttribute("data-scale"),
            };
          },
        },
        {
          tag: "audio source[data-orig-src]",
          getAttrs(dom) {
            return {
              originalSrc: dom.getAttribute("data-orig-src"),
              extras: "audio",
            };
          },
        },
      ],
      toDOM(node) {
        if (node.attrs.extras === "audio") {
          return [
            "audio",
            { preload: "metadata", controls: false, tabindex: -1 },
            ["source", { "data-orig-src": node.attrs.originalSrc }],
          ];
        }

        if (node.attrs.extras === "video") {
          return [
            "div",
            {
              class: "onebox-placeholder-container",
              "data-orig-src": node.attrs.originalSrc,
            },
            ["span", { class: "placeholder-icon video" }],
          ];
        }

        const { originalSrc, extras, scale, placeholder, ...attrs } =
          node.attrs;
        attrs["data-orig-src"] = originalSrc;

        if (extras === "thumbnail") {
          attrs["data-thumbnail"] = true;
        }

        if (scale !== null) {
          attrs["data-scale"] = scale;
        }

        if (placeholder !== null) {
          attrs["data-placeholder"] = placeholder;
        }

        return ["img", attrs];
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
          originalSrc: token.attrGet("data-orig-src"),
          width,
          height,
          scale:
            percent && isNumeric(percent) ? parseInt(percent, 10) : undefined,
          extras,
        };
      },
    },
  },

  serializeNode: {
    image(state, node) {
      if (node.attrs.placeholder) {
        return;
      }

      const alt = (node.attrs.alt || "").replace(/([\\[\]`])/g, "\\$1");
      const scale = node.attrs.scale ? `, ${node.attrs.scale}%` : "";
      const dimensions =
        node.attrs.width && node.attrs.height
          ? `|${node.attrs.width}x${node.attrs.height}${scale}`
          : "";
      const extras = node.attrs.extras ? `|${node.attrs.extras}` : "";
      const src = node.attrs.originalSrc ?? node.attrs.src ?? "";
      const escapedSrc = src.replace(/[\(\)]/g, "\\$&");
      const title = node.attrs.title
        ? ' "' + node.attrs.title.replace(/"/g, '\\"') + '"'
        : "";

      state.write(`![${alt}${dimensions}${extras}](${escapedSrc}${title})`);
    },
  },

  inputRules: ({
    utils: { convertFromMarkdown },
    pmState: { NodeSelection },
  }) => {
    return {
      match: /!\[([^\]]*)\]\(([^)\s]+)\)$/,
      handler: (state, match, start, end) => {
        const tr = state.tr;

        return tr
          .replaceWith(start, end, convertFromMarkdown(match[0]))
          .setSelection(NodeSelection.create(tr.doc, start + 1))
          .scrollIntoView();
      },
    };
  },

  plugins({ pmState: { Plugin, NodeSelection, TextSelection } }) {
    const shortUrlResolver = new Plugin({
      state: {
        init() {
          return [];
        },
        apply(tr, value) {
          let updated = value.slice();

          // we should only track the changes
          tr.doc.descendants((node, pos) => {
            if (node.type.name === "image" && node.attrs.originalSrc) {
              if (node.attrs.src.endsWith(PLACEHOLDER_IMG)) {
                updated.push({ pos, src: node.attrs.originalSrc });
              } else {
                updated = updated.filter(
                  (u) => u.src !== node.attrs.originalSrc
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

    const avoidTextInputRemoval = new Plugin({
      props: {
        handleTextInput(view, from, to, text) {
          const { state } = view;
          const { selection } = state;

          if (
            selection instanceof NodeSelection &&
            selection.node.type.name === "image"
          ) {
            view.dispatch(
              state.tr
                .setSelection(TextSelection.create(state.doc, selection.to - 1))
                .insertText(text)
            );

            return true;
          }

          return false;
        },
      },
    });

    return [shortUrlResolver, avoidTextInputRemoval];
  },
};

export default extension;
