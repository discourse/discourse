import { ajax } from "discourse/lib/ajax";

// computed colors are serialized by the browser, but they still end up in an
// inline style, so anything that isn't plainly a color is dropped
const COLOR_PATTERN = /^(?:[a-z-]+\([\d\sa-z.,%/+-]*\)|#[\da-f]{3,8})$/i;

function safeColor(value) {
  const color = value?.trim();
  return color && COLOR_PATTERN.test(color) ? color : null;
}

function isColorSchemeLink(link) {
  return (
    link.hasAttribute("data-scheme-id") ||
    link.classList.contains("light-scheme") ||
    link.classList.contains("dark-scheme") ||
    link.href.includes("color_definitions") ||
    link.href.includes("color-scheme-stylesheet")
  );
}

function loaded(link) {
  return new Promise((resolve) => {
    link.addEventListener("load", resolve, { once: true });
    link.addEventListener("error", resolve, { once: true });
  });
}

/**
 * @typedef {Object} SidebarColors
 * @property {?string} background - the sidebar background
 * @property {?string} active - the active sidebar link's background
 * @property {?string} link - the sidebar link color
 * @property {?string} border - the divider between sidebar and content, null
 *   when the theme draws none
 */

/**
 * Resolves the colors the current page's theme gives its sidebar under any
 * palette.
 *
 * Themes derive sidebar colors from the palette in their stylesheets, so
 * rather than re-implementing each theme's formulas, the page's own
 * stylesheets are loaded into a hidden frame together with one palette's
 * color definitions at a time, and the colors are read back from a sidebar
 * built there. Requests are queued, so one frame serves every palette.
 */
export default class SidebarColorResolver {
  #themeId;
  #frame;
  #schemeLink;
  #ready;
  #queue = Promise.resolve();
  #destroyed = false;

  /**
   * @param {number} themeId - theme whose color definitions each palette is
   *   compiled against; its stylesheets must be the ones loaded on the page
   */
  constructor(themeId) {
    this.#themeId = themeId;
  }

  /**
   * @param {number} paletteId
   * @param {"light" | "dark"} mode - color scheme the palette is shown in
   * @returns {Promise<?SidebarColors>} null when the colors can't be resolved
   */
  resolve(paletteId, mode) {
    const result = this.#queue.then(() => this.#resolve(paletteId, mode));
    this.#queue = result.catch(() => {});
    return result;
  }

  destroy() {
    this.#destroyed = true;
    this.#frame?.remove();
    this.#frame = null;
  }

  async #resolve(paletteId, mode) {
    if (this.#destroyed) {
      return null;
    }

    const { new_href: href } = await ajax(
      `/color-scheme-stylesheet/${paletteId}/${this.#themeId}.json`
    );
    await (this.#ready ??= this.#buildFrame());

    if (this.#destroyed || !href) {
      return null;
    }

    const doc = this.#frame.contentDocument;
    doc.documentElement.style.colorScheme = mode;
    // assigning an unchanged href fires no load event
    if (this.#schemeLink.getAttribute("href") !== href) {
      const load = loaded(this.#schemeLink);
      this.#schemeLink.setAttribute("href", href);
      await load;
    }

    return this.#read(doc);
  }

  async #buildFrame() {
    const frame = document.createElement("iframe");
    frame.setAttribute("aria-hidden", "true");
    frame.tabIndex = -1;
    // wide enough for the desktop sidebar styles to apply
    frame.style.cssText =
      "position: fixed; top: 0; left: -10000px; width: 1400px; height: 400px; border: 0; visibility: hidden;";
    document.body.append(frame);
    this.#frame = frame;

    const doc = frame.contentDocument;
    doc.documentElement.className = document.documentElement.className;
    doc.body.className = "has-sidebar-page";
    doc.body.innerHTML = `
      <div class="sidebar-wrapper">
        <div class="sidebar-container">
          <span class="design-wizard-sidebar-probe"></span>
        </div>
      </div>`;

    const links = [...document.querySelectorAll("link[rel='stylesheet']")]
      .filter((link) => !isColorSchemeLink(link))
      .map((link) => {
        const copy = doc.createElement("link");
        copy.rel = "stylesheet";
        copy.href = link.href;
        return copy;
      });

    this.#schemeLink = doc.createElement("link");
    this.#schemeLink.rel = "stylesheet";

    doc.head.append(...links, this.#schemeLink);
    await Promise.all(links.map(loaded));
  }

  #read(doc) {
    const view = doc.defaultView;
    const wrapper = doc.querySelector(".sidebar-wrapper");
    const container = doc.querySelector(".sidebar-container");
    const probe = doc.querySelector(".design-wizard-sidebar-probe");

    probe.style.color = "var(--d-sidebar-link-color)";
    probe.style.backgroundColor = "var(--d-sidebar-active-background)";

    const containerStyle = view.getComputedStyle(container);
    const probeStyle = view.getComputedStyle(probe);
    const hasBorder =
      containerStyle.borderRightStyle !== "none" &&
      parseFloat(containerStyle.borderRightWidth) > 0;

    return {
      background: safeColor(view.getComputedStyle(wrapper).backgroundColor),
      active: safeColor(probeStyle.backgroundColor),
      link: safeColor(probeStyle.color),
      border: hasBorder ? safeColor(containerStyle.borderRightColor) : null,
    };
  }
}
