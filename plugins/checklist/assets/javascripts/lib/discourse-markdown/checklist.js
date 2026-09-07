const CHECKLIST_HTML_PATTERN = /\bchcklst-box\b|\bdata-chk-src\b/i;

function neutralizeRawChecklistMarkup(state) {
  const neutralize = (token) => {
    if (
      (token.type === "html_inline" || token.type === "html_block") &&
      CHECKLIST_HTML_PATTERN.test(token.content)
    ) {
      token.type = "text";
      token.tag = "";
      token.nesting = 0;
    }
  };

  for (const block of state.tokens) {
    neutralize(block);
    block.children?.forEach(neutralize);
  }
}

function tokenizeChecklistCandidate(state, silent) {
  const candidate = state.src.slice(state.pos, state.pos + 3);
  const marker = candidate.startsWith("[]")
    ? "[]"
    : candidate.match(/^\[[ xX]\]$/)?.[0];
  if (!marker) {
    return false;
  }

  const sourceOffset = state.pos;
  state.pos += marker.length;

  if (!silent) {
    const token = state.push("checklist_candidate", "", 0);
    token.content = marker;
    token.meta = { checklistSourceOffset: sourceOffset };
  }

  return true;
}

function getClasses(marker) {
  switch (marker) {
    case "[x]":
      return "checked fa fa-square-check-o";
    case "[X]":
      return "checked permanent fa fa-square-check";
    default:
      return "fa fa-square-o";
  }
}

function markerLocations(content, baseLine, lineMarkerCounts) {
  const locations = new Map();
  let line = baseLine;
  let scannedThrough = 0;

  // The ordinal includes markers consumed by other Markdown rules so Ruby can
  // resolve the same physical source position without reimplementing Markdown.
  for (const match of content.matchAll(/\[[ xX]?\]/g)) {
    for (let index = scannedThrough; index < match.index; index += 1) {
      if (content.charCodeAt(index) === 0x0a) {
        line += 1;
      }
    }
    scannedThrough = match.index + match[0].length;

    const nth = lineMarkerCounts.get(line) ?? 0;
    lineMarkerCounts.set(line, nth + 1);
    locations.set(match.index, { line, nth, marker: match[0] });
  }

  return locations;
}

function processChecklist(state) {
  neutralizeRawChecklistMarkup(state);

  if (!state.src.includes("[")) {
    return;
  }

  const sourceLines = state.src.split("\n");
  const sourceLineMarkers = new Map();
  const lineMarkerCounts = new Map();
  let tableRowLine;

  const verifiedLocation = (location) => {
    if (!location) {
      return;
    }

    let markers = sourceLineMarkers.get(location.line);
    if (!markers) {
      markers = [
        ...(sourceLines[location.line] ?? "").matchAll(/\[[ xX]?\]/g),
      ].map((match) => match[0]);
      sourceLineMarkers.set(location.line, markers);
    }

    if (markers[location.nth] === location.marker) {
      return location;
    }
  };

  for (const block of state.tokens) {
    if (block.type === "tr_open") {
      tableRowLine = block.map?.[0];
      continue;
    }
    if (block.type === "tr_close") {
      tableRowLine = undefined;
      continue;
    }
    if (block.type !== "inline") {
      continue;
    }

    const baseLine = block.map?.[0] ?? tableRowLine;
    const locations =
      baseLine === undefined
        ? new Map()
        : markerLocations(block.content, baseLine, lineMarkerCounts);
    const replacements = [];
    let nesting = 0;

    for (let index = 0; index < block.children.length; index += 1) {
      const token = block.children[index];

      if (token.type !== "checklist_candidate") {
        nesting += token.nesting;
        continue;
      }

      if (nesting !== 0) {
        const text = new state.Token("text", "", 0);
        text.content = token.content;
        replacements.push({ index, newTokens: [text] });
        continue;
      }

      const checkbox = new state.Token("check_open", "span", 1);
      checkbox.attrs = [["class", `chcklst-box ${getClasses(token.content)}`]];

      if (baseLine !== undefined && token.content !== "[X]") {
        const location = verifiedLocation(
          locations.get(token.meta.checklistSourceOffset)
        );
        if (location) {
          checkbox.attrs.push([
            "data-chk-src",
            `${location.line}:${location.nth}`,
          ]);
        }
      }

      replacements.push({
        index,
        newTokens: [checkbox, new state.Token("check_close", "span", -1)],
      });
    }

    for (let index = replacements.length - 1; index >= 0; index -= 1) {
      block.children = state.md.utils.arrayReplaceAt(
        block.children,
        replacements[index].index,
        replacements[index].newTokens
      );
    }
  }
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.features.checklist = !!siteSettings.checklist_enabled;
  });

  helper.allowList([
    "span.chcklst-stroked",
    "span.chcklst-box fa fa-square-o",
    "span.chcklst-box checked fa fa-square-check-o",
    "span.chcklst-box checked permanent fa fa-square-check",
    "span[data-chk-src]",
  ]);

  helper.registerPlugin((md) => {
    md.inline.ruler.push("checklist_candidate", tokenizeChecklistCandidate);
    md.core.ruler.before("text_join", "checklist", processChecklist);
  });
}
