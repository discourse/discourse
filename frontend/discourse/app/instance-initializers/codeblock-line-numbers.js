import { withPluginApi } from "discourse/lib/plugin-api";

function addGutters(element) {
  const gutters = new Map();

  for (const code of element.querySelectorAll("pre > code")) {
    const pre = code.parentElement;
    if (
      pre.closest("aside, .onebox") ||
      code.classList.contains("lang-mermaid") ||
      pre.classList.contains("codeblock-numbered")
    ) {
      continue;
    }

    const lines = code.textContent.replace(/\n$/, "").split("\n").length;
    if (lines < 2) {
      continue;
    }

    const gutter = document.createElement("span");
    gutter.className = "codeblock-line-numbers";
    gutter.setAttribute("aria-hidden", "true");
    gutter.textContent = Array.from({ length: lines }, (_, i) => i + 1).join(
      "\n"
    );
    pre.classList.add("codeblock-numbered");
    code.before(gutter);
    gutters.set(code, gutter);
  }

  if (!gutters.size) {
    return;
  }

  const resizeObserver = new ResizeObserver((entries) => {
    const sizes = entries.map(({ target }) => {
      const style = getComputedStyle(target);
      return {
        target,
        height: target.clientHeight,
        fontFamily: style.fontFamily,
        fontSize: style.fontSize,
        lineHeight: style.lineHeight,
        paddingBlock: style.paddingBlock,
        scrollTop: target.scrollTop,
      };
    });
    for (const { target, height, scrollTop, ...style } of sizes) {
      const gutter = gutters.get(target);
      Object.assign(gutter.style, style, { blockSize: `${height}px` });
      gutter.scrollTop = scrollTop;
    }
  });

  function syncScroll({ currentTarget }) {
    gutters.get(currentTarget).scrollTop = currentTarget.scrollTop;
  }

  for (const code of gutters.keys()) {
    resizeObserver.observe(code);
    code.addEventListener("scroll", syncScroll, { passive: true });
  }

  return () => {
    resizeObserver.disconnect();
    for (const [code, gutter] of gutters) {
      code.removeEventListener("scroll", syncScroll);
      code.parentElement?.classList.remove("codeblock-numbered");
      gutter.remove();
    }
  };
}

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    if (siteSettings.show_codeblock_line_numbers) {
      withPluginApi((api) => {
        api.decorateCookedElement(addGutters, { onlyStream: true });
      });
    }
  },
};
