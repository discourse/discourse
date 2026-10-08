import AiArtifactNodeView from "../components/ai-artifact-node-view";

const SHARE_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const DECIMAL_PATTERN = /^[0-9]{1,19}$/;
const HEIGHT_PATTERN = /^[0-9]{1,19}$/;

function normalizedHeight(value) {
  if (value == null || !HEIGHT_PATTERN.test(value)) {
    return null;
  }
  const height = Number(value);
  return height > 0 && height <= 2000 ? String(height) : null;
}

const TAG_PATTERN = /^\[ai-artifact((?:[ \t]+[a-z]+="[^"\r\n]*")+)\]$/;
const ATTRIBUTE_PATTERN = /[ \t]+([a-z]+)="([^"\r\n]*)"/g;

function normalizeIdentity({ share, id, version, autorun }) {
  if (
    autorun !== null &&
    autorun !== undefined &&
    !["true", "false"].includes(autorun)
  ) {
    return;
  }

  if (share !== null && share !== undefined) {
    if (id != null || version != null || !SHARE_PATTERN.test(share)) {
      return;
    }
    return { share, id: null, version: null, autorun: autorun ?? null };
  }

  if (
    !DECIMAL_PATTERN.test(id || "") ||
    (version != null && !DECIMAL_PATTERN.test(version))
  ) {
    return;
  }

  id = id.replace(/^0+/, "");
  if (!id) {
    return;
  }

  return {
    share: null,
    id,
    version: version?.replace(/^0+/, "") || null,
    autorun: autorun ?? null,
  };
}

function parseTag(tag) {
  const match = TAG_PATTERN.exec(tag);
  if (!match) {
    return;
  }

  const attrs = Object.create(null);
  for (const [, name, value] of match[1].matchAll(ATTRIBUTE_PATTERN)) {
    if (
      !["share", "id", "version", "autorun", "height", "seamless"].includes(
        name
      ) ||
      name in attrs
    ) {
      return;
    }
    attrs[name] = value;
  }

  const identity = normalizeIdentity(attrs);
  const height = attrs.height == null ? null : normalizedHeight(attrs.height);
  if (
    !identity ||
    (attrs.height != null && height === null) ||
    (attrs.seamless != null && !["true", "false"].includes(attrs.seamless))
  ) {
    return;
  }
  return { ...identity, height, seamless: attrs.seamless ?? null };
}

function attrsFromDOM(dom) {
  const autorun = dom.getAttribute("data-ai-artifact-autorun");
  const identity = normalizeIdentity({
    share: dom.getAttribute("data-ai-artifact-share-key"),
    id: dom.getAttribute("data-ai-artifact-id"),
    version: dom.getAttribute("data-ai-artifact-version"),
    autorun:
      autorun == null
        ? null
        : autorun === "" || autorun === "1" || autorun === "true"
          ? "true"
          : "false",
  });
  if (!identity) {
    return false;
  }

  return {
    ...identity,
    height: dom.getAttribute("data-ai-artifact-height"),
    width: dom.getAttribute("data-ai-artifact-width"),
    seamless: dom.getAttribute("data-ai-artifact-seamless"),
  };
}

function compactTag({ share, id, version, autorun, height, seamless }) {
  const identity = share ? `share="${share}"` : `id="${id}"`;
  return `[ai-artifact ${identity}${version ? ` version="${version}"` : ""}${autorun != null ? ` autorun="${autorun}"` : ""}${height != null ? ` height="${normalizedHeight(height)}"` : ""}${seamless != null ? ` seamless="${seamless}"` : ""}]`;
}

function escapeAttribute(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function artifactHTML(attrs) {
  const dataAttrs = {
    "data-ai-artifact-share-key": attrs.share,
    "data-ai-artifact-id": attrs.id,
    "data-ai-artifact-version": attrs.version,
    "data-ai-artifact-autorun": attrs.autorun,
    "data-ai-artifact-height": attrs.height,
    "data-ai-artifact-width": attrs.width,
    "data-ai-artifact-seamless": attrs.seamless,
  };
  const attributes = Object.entries(dataAttrs)
    .filter(([, value]) => value != null)
    .map(([name, value]) => ` ${name}="${escapeAttribute(value)}"`)
    .join("");
  return `<div class="ai-artifact"${attributes}></div>`;
}

function artifactMarkdown(attrs) {
  return attrs.width != null ||
    (attrs.height != null && normalizedHeight(attrs.height) === null) ||
    (attrs.seamless != null && !["true", "false"].includes(attrs.seamless))
    ? artifactHTML(attrs)
    : compactTag(attrs);
}

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  nodeViews: {
    ai_artifact: { component: AiArtifactNodeView },
  },

  nodeSpec: {
    ai_artifact: {
      attrs: {
        share: { default: null },
        id: { default: null },
        version: { default: null },
        autorun: { default: null },
        height: { default: null },
        width: { default: null },
        seamless: { default: null },
      },
      group: "block",
      atom: true,
      defining: true,
      isolating: true,
      selectable: true,
      createGapCursor: true,
      parseDOM: [
        { tag: "div.ai-artifact", getAttrs: attrsFromDOM },
        { tag: "div.composer-ai-artifact", getAttrs: attrsFromDOM },
      ],
      toDOM(node) {
        const attrs = node.attrs;
        const dataAttrs = {
          class: "composer-ai-artifact",
          contenteditable: "false",
          "data-ai-artifact-share-key": attrs.share,
          "data-ai-artifact-id": attrs.id,
          "data-ai-artifact-version": attrs.version,
          "data-ai-artifact-autorun": attrs.autorun,
          "data-ai-artifact-height": attrs.height,
          "data-ai-artifact-width": attrs.width,
          "data-ai-artifact-seamless": attrs.seamless,
        };
        return ["div", dataAttrs, artifactMarkdown(attrs)];
      },
    },
  },

  parse: {
    ai_artifact(state, token) {
      const { legacy, ...attrs } = token.meta || {};
      const identity = normalizeIdentity({
        ...attrs,
        autorun:
          legacy && attrs.autorun != null
            ? ["", "1", "true"].includes(attrs.autorun)
              ? "true"
              : "false"
            : attrs.autorun,
      });
      if (identity) {
        state.addNode(state.schema.nodes.ai_artifact, {
          ...identity,
          height: attrs.height ?? null,
          width: attrs.width ?? null,
          seamless: attrs.seamless ?? null,
        });
      }
      return true;
    },
  },

  serializeNode: {
    ai_artifact(state, node) {
      state.write(artifactMarkdown(node.attrs));
      state.closeBlock(node);
    },
  },

  inputRules: ({ schema }) => ({
    match: /^\[ai-artifact(?:[ \t]+[a-z]+="[^"\r\n]*")+\]$/,
    handler(state, match, start, end) {
      const attrs = parseTag(match[0]);
      if (!attrs) {
        return null;
      }
      return state.tr.replaceWith(
        start - 1,
        end,
        schema.nodes.ai_artifact.create(attrs)
      );
    },
  }),
  plugins: ({ pmState: { Plugin }, pmModel: { Slice, Fragment }, schema }) =>
    new Plugin({
      props: {
        transformPasted(slice, view) {
          const { $from } = view.state.selection;
          if (
            $from.parent.type.name !== "paragraph" ||
            $from.parent.content.size !== 0 ||
            view.state.storedMarks?.some((mark) => mark.type.name === "code")
          ) {
            return slice;
          }

          const paragraph = slice.content.firstChild;
          if (
            slice.content.childCount !== 1 ||
            paragraph?.type.name !== "paragraph" ||
            paragraph.childCount !== 1 ||
            !paragraph.firstChild.isText ||
            paragraph.firstChild.marks.length
          ) {
            return slice;
          }

          const attrs = parseTag(paragraph.textContent);
          return attrs
            ? new Slice(
                Fragment.from(schema.nodes.ai_artifact.create(attrs)),
                0,
                0
              )
            : slice;
        },
      },
    }),
};

export default extension;
