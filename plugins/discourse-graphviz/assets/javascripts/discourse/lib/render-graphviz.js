import { trustHTML } from "@ember/template";
import { hrefAllowed } from "pretty-text/sanitizer";
import loadScript from "discourse/lib/load-script";

let vizPromise;

function loadViz() {
  vizPromise ??= loadScript(
    "/plugins/discourse-graphviz/javascripts/viz-3.0.1.js"
  );
  return vizPromise;
}

// viz.js does not sanitize its output, so strip dangerous links and attributes
// before the SVG is injected into the page.
export function sanitizeGraphvizSvg(svg) {
  svg.querySelectorAll("script, foreignObject").forEach((el) => el.remove());

  svg.querySelectorAll("*").forEach((el) => {
    for (const attr of [...el.attributes]) {
      const name = attr.name.toLowerCase();
      if (name.startsWith("on") || /javascript:/i.test(attr.value)) {
        el.removeAttribute(attr.name);
      }
    }
  });

  svg.querySelectorAll("a").forEach((anchor) => {
    const href =
      anchor.getAttribute("href") || anchor.getAttribute("xlink:href");
    // Allow only http/https and relative/anchor links; drop mailto, which hrefAllowed otherwise permits.
    if (href && (!hrefAllowed(href) || /^\s*mailto:/i.test(href))) {
      anchor.replaceWith(...anchor.childNodes);
    }
  });

  return svg;
}

export async function generateGraph(source, engine) {
  await loadViz();

  /* global vizRenderStringSync */
  const rendered = vizRenderStringSync(source, { format: "svg", engine });

  const doc = new DOMParser().parseFromString(rendered, "image/svg+xml");
  if (doc.querySelector("parsererror")) {
    throw new Error(doc.querySelector("parsererror").textContent);
  }

  return trustHTML(sanitizeGraphvizSvg(doc.documentElement).outerHTML);
}
