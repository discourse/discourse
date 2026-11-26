function findSystemNodes(selector, xpath, steps, pierceShadow) {
  if (!this.isConnected) {
    throw new Error("NativeStaleElement");
  }

  const textSelector = /:(has-text|text-is)\(\s*("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')\s*\)/g;
  const normalize = (text) => text.replace(/\s+/g, " ").trim();

  function queryText(root, css) {
    const marked = [];
    const nonce = Math.random().toString(36).slice(2);
    let ordinal = 0;
    const selector = css.replace(textSelector, (_, kind, quoted) => {
      const text = normalize(quoted.slice(1, -1).replace(/\\([\\'"])/g, "$1"));
      const attribute = `data-discourse-system-text-${nonce}-${ordinal++}`;
      const mark = (element) => {
        const content = normalize(element.textContent);
        const matches = kind === "text-is" ? content === text : content.toLowerCase().includes(text.toLowerCase());
        if (matches) {
          element.setAttribute(attribute, "");
          marked.push([element, attribute]);
        }
      };
      if (root instanceof Element) {
        mark(root);
      }
      root.querySelectorAll("*").forEach(mark);
      return `[${attribute}]`;
    });

    try {
      return Array.from(root.querySelectorAll(selector));
    } finally {
      for (const [element, attribute] of marked) {
        element.removeAttribute(attribute);
      }
    }
  }

  function query(root, css) {
    const matches = css.includes(":has-text(") || css.includes(":text-is(")
      ? queryText(root, css)
      : Array.from(root.querySelectorAll(css));
    if (pierceShadow) {
      if (root.shadowRoot) {
        matches.push(...query(root.shadowRoot, css));
      }
      for (const element of root.querySelectorAll("*")) {
        if (element.shadowRoot) {
          matches.push(...query(element.shadowRoot, css));
        }
      }
    }
    return matches;
  }

  if (steps) {
    return steps.reduce((roots, step) => {
      if (Number.isInteger(step)) {
        return roots.at(step) ? [roots.at(step)] : [];
      }
      return Array.from(new Set(roots.flatMap((root) => query(root, step))));
    }, [this]);
  }
  if (!xpath) {
    return query(this, selector);
  }
  const results = document.evaluate(selector, this, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
  return Array.from({ length: results.snapshotLength }, (_, index) => results.snapshotItem(index));
}
