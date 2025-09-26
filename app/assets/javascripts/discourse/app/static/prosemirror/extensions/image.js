import {
  lookupCachedUploadUrl,
  lookupUncachedUploadUrls,
} from "pretty-text/upload-short-url";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { isNumeric } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import ImageNodeView from "../components/image-node-view";
import GlimmerNodeView from "../lib/glimmer-node-view";
import { getChangedRanges } from "../lib/plugin-utils";

const PLACEHOLDER_IMG = "/images/transparent.png";

const ALT_TEXT_REGEX =
  /^(.*?)(?:\|(\d{1,4}x\d{1,4}))?(?:,\s*(\d{1,3})%)?(?:\|(.*))?$/;

const UPLOAD_TIMEOUT = 30_000;

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
      match: /!\[[^\]]*\]\([^\s]+\)$/,
      handler: (state, match, start, end) => {
        const tr = state.tr;

        return tr
          .replaceWith(start, end, convertFromMarkdown(match[0]))
          .setSelection(NodeSelection.create(tr.doc, start + 2))
          .scrollIntoView();
      },
    };
  },

  plugins({ pmState: { Plugin, NodeSelection, TextSelection }, getContext }) {
    const shortUrlResolver = new Plugin({
      state: {
        init() {
          return [];
        },
        apply(tr, value) {
          let updated = value.slice();

          getChangedRanges(tr).forEach(({ new: { from, to } }) => {
            tr.doc.nodesBetween(from, to, (node, pos) => {
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
          });

          return updated;
        },
      },

      view() {
        const processUrls = async (view) => {
          const unresolvedUrls = shortUrlResolver.getState(view.state);
          if (!unresolvedUrls.length) {
            return;
          }

          const resolvedUrls = {};
          const uncachedSrcs = [];

          for (const { src } of unresolvedUrls) {
            const cachedUrl = lookupCachedUploadUrl(src).url;
            if (cachedUrl) {
              resolvedUrls[src] = cachedUrl;
            } else {
              uncachedSrcs.push(src);
            }
          }

          if (uncachedSrcs.length > 0) {
            const results = await lookupUncachedUploadUrls(uncachedSrcs, ajax);

            for (const result of results) {
              if (result?.url && result?.short_url) {
                resolvedUrls[result.short_url] = result.url;
              }
            }
          }

          const tr = view.state.tr.setMeta("addToHistory", false);

          for (const { pos, src } of unresolvedUrls) {
            const url = resolvedUrls[src];

            if (!url) {
              continue;
            }

            const node = view.state.doc.nodeAt(pos);
            if (!node) {
              continue;
            }

            tr.setNodeMarkup(pos, null, { ...node.attrs, src: url });
          }

          view.dispatch(tr);
        };

        return {
          update: (view, prevState) => {
            if (prevState.doc.eq(view.state.doc)) {
              return;
            }
            discourseDebounce(null, processUrls, view, 100);
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

    const dataImageUploader = new Plugin({
      state: {
        init() {
          return new Map();
        },
        apply(tr, uriNodesMap) {
          getChangedRanges(tr).forEach(({ new: { from, to } }) => {
            tr.doc.nodesBetween(from, to, (node, pos) => {
              if (
                node.type.name === "image" &&
                node.attrs.src?.startsWith("data:")
              ) {
                if (!uriNodesMap.has(node.attrs.src)) {
                  uriNodesMap.set(node.attrs.src, []);
                }
                uriNodesMap.get(node.attrs.src).push({ node, pos });
              } else if (node.type.name === "image" && node.attrs.src) {
                for (const [dataURI, nodes] of uriNodesMap) {
                  uriNodesMap.set(
                    dataURI,
                    nodes.filter((n) => n.pos !== pos)
                  );
                  if (uriNodesMap.get(dataURI).length === 0) {
                    uriNodesMap.delete(dataURI);
                  }
                }
              }
            });
          });

          return uriNodesMap;
        },
      },

      view() {
        const { appEvents } = getContext();
        const pendingUploads = new Set();

        const uploadDataImage = async (dataURI, nodes, view) => {
          const mimeMatch = dataURI.match(/data:image\/([^;]+)/);
          let fileExtension = "png";
          if (mimeMatch) {
            const remap = { jpeg: "jpg" };
            const ext = mimeMatch[1].toLowerCase();
            fileExtension = remap[ext] || ext;
          }

          const fileName = `image-${Date.now()}-${Math.random().toString(36).substr(2, 9)}.${fileExtension}`;

          const res = await fetch(dataURI);
          const blob = await res.blob();
          const file = new File([blob], fileName, { type: blob.type });
          file.id = fileName;
          pendingUploads.add(fileName);

          const handleSuccess = (uploadedFileName, upload) => {
            if (uploadedFileName === fileName && pendingUploads.has(fileName)) {
              if (!upload?.short_url && !upload?.url) {
                return handleError(fileName);
              }

              const tr = view.state.tr;

              nodes.forEach(({ pos }) => {
                const node = view.state.doc.nodeAt(pos);
                if (node && node.type.name === "image") {
                  tr.setNodeMarkup(pos, null, {
                    ...node.attrs,
                    alt:
                      node.attrs.alt ||
                      i18n("upload_selector.default_image_alt_text"),
                    src: upload.url || upload.short_url,
                    originalSrc: upload.short_url || upload.url,
                  });
                }
              });

              if (tr.docChanged) {
                view.dispatch(tr);
              }
              cleanup();
            }
          };

          const handleError = (uploadedFileName) => {
            if (
              (uploadedFileName === fileName || !uploadedFileName) &&
              pendingUploads.has(fileName)
            ) {
              const tr = view.state.tr;
              nodes.forEach(({ pos }) => {
                const node = view.state.doc.nodeAt(pos);
                if (node && node.type.name === "image") {
                  tr.replaceWith(
                    pos,
                    pos + node.nodeSize,
                    view.state.schema.text("[Upload failed]")
                  );
                }
              });
              if (tr.docChanged) {
                view.dispatch(tr);
              }
              cleanup();
            }
          };

          const cleanup = () => {
            pendingUploads.delete(fileName);
            appEvents.off("composer:upload-success", handleSuccess);
            appEvents.off("composer:upload-error", handleError);
          };

          appEvents.on("composer:upload-success", handleSuccess);
          appEvents.on("composer:upload-error", handleError);

          appEvents.trigger("composer:add-files", [file], {
            skipPlaceholder: true,
          });

          setTimeout(() => {
            if (pendingUploads.has(fileName)) {
              handleError(fileName);
            }
          }, UPLOAD_TIMEOUT);
        };

        return {
          update(view) {
            dataImageUploader
              .getState(view.state)
              .forEach((nodes, dataURI) =>
                uploadDataImage(dataURI, nodes, view)
              );
          },
        };
      },
    });

    return [shortUrlResolver, avoidTextInputRemoval, dataImageUploader];
  },
};

export default extension;
