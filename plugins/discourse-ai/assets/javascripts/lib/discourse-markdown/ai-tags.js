const TAG_PATTERN = /^\[ai-artifact((?:[ \t]+[a-z]+="[^"\r\n]*")+)\]$/;
const ATTRIBUTE_PATTERN = /[ \t]+([a-z]+)="([^"\r\n]*)"/g;
const SHARE_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const DECIMAL_PATTERN = /^[0-9]{1,19}$/;
const HEIGHT_PATTERN = /^[0-9]{1,19}$/;
const LEGACY_DIV_PATTERN = /^<div((?:[ \t]+[a-z-]+="[^"<>]*")+)[ \t]*><\/div>$/;
const LEGACY_ATTR_PATTERN = /[ \t]+([a-z-]+)="([^"<>]*)"/g;
const LEGACY_DATA_ATTRS = [
  "data-ai-artifact-share-key",
  "data-ai-artifact-id",
  "data-ai-artifact-version",
  "data-ai-artifact-autorun",
  "data-ai-artifact-height",
  "data-ai-artifact-width",
  "data-ai-artifact-seamless",
];

function normalizedHeight(value) {
  if (value === undefined || !HEIGHT_PATTERN.test(value)) {
    return value === undefined ? undefined : null;
  }
  const height = Number(value);
  return height > 0 && height <= 2000 ? String(height) : null;
}

function parseArtifact(line) {
  const match = TAG_PATTERN.exec(line);
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

  if (
    attrs.autorun !== undefined &&
    attrs.autorun !== "true" &&
    attrs.autorun !== "false"
  ) {
    return;
  }

  const height = normalizedHeight(attrs.height);
  if (
    height === null ||
    (attrs.seamless !== undefined &&
      attrs.seamless !== "true" &&
      attrs.seamless !== "false")
  ) {
    return;
  }

  if (attrs.share !== undefined) {
    if (
      attrs.id !== undefined ||
      attrs.version !== undefined ||
      !SHARE_PATTERN.test(attrs.share)
    ) {
      return;
    }
    return {
      share: attrs.share,
      autorun: attrs.autorun,
      height,
      seamless: attrs.seamless,
    };
  }

  if (
    !DECIMAL_PATTERN.test(attrs.id || "") ||
    (attrs.version !== undefined && !DECIMAL_PATTERN.test(attrs.version))
  ) {
    return;
  }

  const id = attrs.id.replace(/^0+/, "");
  if (!id) {
    return;
  }

  const version = attrs.version?.replace(/^0+/, "");
  return {
    id,
    version,
    autorun: attrs.autorun,
    height,
    seamless: attrs.seamless,
  };
}

function parseLegacyArtifact(line, unescapeAll) {
  const match = LEGACY_DIV_PATTERN.exec(line);
  if (!match) {
    return;
  }

  const attrs = Object.create(null);
  for (const [, name, value] of match[1].matchAll(LEGACY_ATTR_PATTERN)) {
    if (
      (name !== "class" && !LEGACY_DATA_ATTRS.includes(name)) ||
      name in attrs
    ) {
      return;
    }
    attrs[name] = unescapeAll(value);
  }

  if (attrs.class !== "ai-artifact") {
    return;
  }

  const share = attrs["data-ai-artifact-share-key"];
  const id = attrs["data-ai-artifact-id"];
  const version = attrs["data-ai-artifact-version"];
  if (share !== undefined) {
    if (
      id !== undefined ||
      version !== undefined ||
      !SHARE_PATTERN.test(share)
    ) {
      return;
    }
  } else if (
    !DECIMAL_PATTERN.test(id || "") ||
    (version !== undefined && !DECIMAL_PATTERN.test(version)) ||
    !id.replace(/^0+/, "")
  ) {
    return;
  }

  return {
    legacy: line,
    share,
    id,
    version,
    autorun: attrs["data-ai-artifact-autorun"],
    height: attrs["data-ai-artifact-height"],
    width: attrs["data-ai-artifact-width"],
    seamless: attrs["data-ai-artifact-seamless"],
  };
}

function legacyArtifactBlock(state, startLine, _endLine, silent) {
  if (!state.md.options.discourse.features.aiArtifact) {
    return false;
  }

  const start = state.bMarks[startLine] + state.tShift[startLine];
  const artifact = parseLegacyArtifact(
    state.src.slice(start, state.eMarks[startLine]).trimEnd(),
    state.md.utils.unescapeAll
  );
  if (!artifact) {
    return false;
  }
  if (silent) {
    return true;
  }

  const token = state.push("ai_artifact", "", 0);
  token.block = true;
  token.meta = artifact;
  state.line = startLine + 1;
  return true;
}

function artifactBlock(state, startLine, _endLine, silent) {
  if (!state.md.options.discourse.features.aiArtifact) {
    return false;
  }

  const start = state.bMarks[startLine] + state.tShift[startLine];
  const line = state.src.slice(start, state.eMarks[startLine]).trimEnd();
  const artifact = parseArtifact(line);
  if (!artifact) {
    return false;
  }

  if (silent) {
    return true;
  }

  const token = state.push("ai_artifact", "", 0);
  token.block = true;
  token.meta = artifact;
  state.line = startLine + 1;
  return true;
}

export function setup(helper) {
  helper.allowList(["details[class=ai-quote]", "details[class=ai-thinking]"]);
  helper.allowList([
    "div[class=ai-artifact]",
    "div[data-ai-artifact-id]",
    "div[data-ai-artifact-version]",
    "div[data-ai-artifact-share-key]",
    "div[data-ai-artifact-autorun]",
    "div[data-ai-artifact-height]",
    "div[data-ai-artifact-width]",
    "div[data-ai-artifact-seamless]",
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.aiArtifact = !!siteSettings.discourse_ai_enabled;
  });

  helper.registerPlugin((md) => {
    md.block.ruler.before(
      "html_block",
      "ai_artifact_legacy",
      legacyArtifactBlock,
      {
        alt: ["paragraph", "reference", "blockquote", "list"],
      }
    );
    md.block.ruler.before("paragraph", "ai_artifact", artifactBlock, {
      alt: ["paragraph", "reference", "blockquote", "list"],
    });
    md.renderer.rules.ai_artifact = (tokens, idx) => {
      const { id, version, share, autorun, height, seamless, legacy } =
        tokens[idx].meta;
      if (legacy) {
        return `${legacy}\n`;
      }
      const heightAttr =
        height !== undefined ? ` data-ai-artifact-height="${height}"` : "";
      const seamlessAttr =
        seamless !== undefined
          ? ` data-ai-artifact-seamless="${seamless}"`
          : "";
      const autorunAttr =
        autorun !== undefined ? ` data-ai-artifact-autorun="${autorun}"` : "";
      if (share) {
        return `<div class="ai-artifact" data-ai-artifact-share-key="${share}"${autorunAttr}${heightAttr}${seamlessAttr}></div>\n`;
      }
      const versionAttr = version
        ? ` data-ai-artifact-version="${version}"`
        : "";
      return `<div class="ai-artifact" data-ai-artifact-id="${id}"${versionAttr}${autorunAttr}${heightAttr}${seamlessAttr}></div>\n`;
    };
  });
}
