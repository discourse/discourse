// Table rows are split before inline Markdown is parsed, so pipes inside links
// need a same-length placeholder until block parsing has finished. Normalize
// has already replaced source NULs before this rule runs.
const PIPE_PLACEHOLDER = "\0";

function linkEndWithPipe(inlineState, start, isImage) {
  const { md, src } = inlineState;
  const inlineEnd = inlineState.pos;
  const labelMarker = start + (isImage ? 1 : 0);
  const labelEnd = md.helpers.parseLinkLabel(
    inlineState,
    labelMarker,
    !isImage
  );
  if (labelEnd < 0) {
    return;
  }

  const destinationMarker = labelEnd + 1;
  let end;

  if (src[destinationMarker] === "(" && inlineEnd > destinationMarker + 1) {
    end = inlineEnd;
  } else if (src[destinationMarker] === "[") {
    // Reference definitions are not collected until block parsing.
    const referenceEnd = md.helpers.parseLinkLabel(
      inlineState,
      destinationMarker
    );
    if (referenceEnd >= 0) {
      end = referenceEnd + 1;
    }
  }

  return end && src.slice(start, end).includes("|") ? end : undefined;
}

function protectLinePipes(md, env, line) {
  if (!line.includes("|") || !line.includes("[")) {
    return line;
  }

  const inlineState = new md.inline.State(line, md, env, []);
  let output = "";
  let copiedUntil = 0;

  while (inlineState.pos < line.length) {
    const start = inlineState.pos;
    const isImage = line.startsWith("![", start);
    md.inline.skipToken(inlineState);

    if (!isImage && line[start] !== "[") {
      continue;
    }

    const end = linkEndWithPipe(inlineState, start, isImage);
    if (end !== undefined) {
      output += line.slice(copiedUntil, start);
      output += line.slice(start, end).replaceAll("|", PIPE_PLACEHOLDER);
      copiedUntil = end;
      inlineState.pos = end;
    }
  }

  return copiedUntil ? output + line.slice(copiedUntil) : line;
}

function protectLinkPipes(state) {
  if (!state.src.includes("|") || !state.src.includes("[")) {
    return;
  }

  state.src = state.src
    .split("\n")
    .map((line) => protectLinePipes(state.md, state.env, line))
    .join("\n");
}

function restoreLinkPipes(state) {
  if (!state.src.includes(PIPE_PLACEHOLDER)) {
    return;
  }

  for (const token of state.tokens) {
    if (token.content?.includes(PIPE_PLACEHOLDER)) {
      token.content = token.content.replaceAll(PIPE_PLACEHOLDER, "|");
    }
    if (token.info?.includes(PIPE_PLACEHOLDER)) {
      token.info = token.info.replaceAll(PIPE_PLACEHOLDER, "|");
    }
  }

  state.src = state.src.replaceAll(PIPE_PLACEHOLDER, "|");
}

export function setup(helper) {
  helper.registerPlugin((md) => {
    md.core.ruler.after("normalize", "protect_link_pipes", protectLinkPipes);
    md.core.ruler.after("block", "restore_link_pipes", restoreLinkPipes);

    md.renderer.rules.table_open = function () {
      return '<div class="md-table">\n<table>\n';
    };

    md.renderer.rules.table_close = function () {
      return "</table>\n</div>";
    };
  });

  // we need a custom callback for style handling
  helper.allowList({
    custom(tag, attr, val) {
      if (tag !== "th" && tag !== "td") {
        return false;
      }

      if (attr !== "style") {
        return false;
      }

      return (
        val === "text-align:right" ||
        val === "text-align:left" ||
        val === "text-align:center"
      );
    },
  });

  helper.allowList([
    "table",
    "tbody",
    "thead",
    "tr",
    "th",
    "th[colspan]",
    "th[rowspan]",
    "td",
    "td[colspan]",
    "td[rowspan]",
    "div.md-table",
  ]);
}
