import { makeArray } from "discourse/lib/helpers";

function highlight(node, pattern, nodeName, className) {
  if (
    ![Node.ELEMENT_NODE, Node.TEXT_NODE].includes(node.nodeType) ||
    ["SCRIPT", "STYLE"].includes(node.tagName) ||
    (node.tagName === nodeName && node.className === className)
  ) {
    return 0;
  }

  if (node.nodeType === Node.ELEMENT_NODE && node.childNodes) {
    for (let i = 0; i < node.childNodes.length; i++) {
      i += highlight(node.childNodes[i], pattern, nodeName, className);
    }
    return 0;
  }

  if (node.nodeType === Node.TEXT_NODE) {
    let match;
    try {
      match = node.data.match(pattern);
    } catch {
      // If the regex is too large, it will throw an error.
      // In this case, we just return the original node without highlighting.
      return 0;
    }

    if (!match) {
      return 0;
    }

    const element = document.createElement(nodeName);
    element.className = className;
    element.innerText = match[2];

    const matchNode = node.splitText(match.index + match[1].length);
    matchNode.splitText(match[2].length);
    matchNode.parentNode.replaceChild(element, matchNode);
    return 1;
  }

  return 0;
}

export default function (node, words, opts = {}) {
  let settings = {
    nodeName: "span",
    className: "highlighted",
    matchCase: false,
    partialMatch: false,
  };

  settings = { ...settings, ...opts };

  words = makeArray(words)
    .filter(Boolean)
    .map((word) => word.replace(/[-\/\\^$*+?.()|[\]{}]/g, "\\$&"));

  if (!words.length) {
    return node;
  }

  let pattern;
  if (settings.partialMatch) {
    // For partial matching, don't require word boundaries
    pattern = `()(${words.join("|")})()`;
  } else {
    // Original exact word matching with word boundaries
    pattern = `(\\W|^)(${words.join(" ")})(\\W|$)`;
  }

  let flag;

  if (!settings.matchCase) {
    flag = "i";
  }

  highlight(
    node,
    new RegExp(pattern, flag),
    settings.nodeName.toUpperCase(),
    settings.className
  );

  return node;
}

export function unhighlightHTML(opts = {}) {
  let settings = {
    nodeName: "span",
    className: "highlighted",
  };

  settings = { ...settings, ...opts };

  document
    .querySelectorAll(`${settings.nodeName}.${settings.className}`)
    .forEach((element) => {
      const parentNode = element.parentNode;
      parentNode.replaceChild(element.firstChild, element);
      parentNode.normalize();
    });
}
