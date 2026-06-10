import { trustHTML } from "@ember/template";
import { hrefAllowed } from "pretty-text/sanitizer";
import loadViz from "discourse/lib/load-viz";

let vizPromise;

function vizInstance() {
  vizPromise ??= loadViz().then((module) => module.instance());
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
  const viz = await vizInstance();
  const svg = viz.renderSVGElement(source, { engine });
  return trustHTML(sanitizeGraphvizSvg(svg).outerHTML);
}
