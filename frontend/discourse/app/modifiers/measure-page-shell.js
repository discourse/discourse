import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import { PANEL_LIMITS } from "discourse/services/page-shell";

export default class MeasurePageShell extends Modifier {
  @service pageShell;
  @service site;

  modify(element, [, , , navigationWidth, contextWidth]) {
    element.style.setProperty(
      "--_page-shell-navigation-width",
      `${navigationWidth}px`
    );
    element.style.setProperty(
      "--_page-shell-context-width",
      `${contextWidth}px`
    );
    if (!this.measure) {
      this.setup(element);
    }
    this.measure?.();
  }

  setup(element) {
    const content = element.querySelector(".page-shell__main-content");
    if (!content) {
      return;
    }
    const headerStart = element.querySelector(".page-shell__header-start");
    const headerEnd = element.querySelector(".d-header .contents > .panel");
    const body = element.querySelector(".page-shell__main");
    const footer = element.querySelector(".page-shell__footer");
    const headerWrap = element.querySelector(".d-header > .wrap");
    element.style.setProperty(
      "--_page-shell-navigation-default-width",
      `${PANEL_LIMITS.navigation.defaultWidth}px`
    );
    element.style.setProperty(
      "--_page-shell-context-default-width",
      `${PANEL_LIMITS.context.defaultWidth}px`
    );
    let fullHeaderStartWidth = 0;

    let frame;
    const measure = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        // Document offsets stay stable when a preceding bar scrolls away.
        element.style.setProperty(
          "--_page-shell-document-offset",
          `${element.getBoundingClientRect().top + window.scrollY}px`
        );
        if (body) {
          element.style.setProperty(
            "--_page-shell-body-offset",
            `${body.getBoundingClientRect().top + window.scrollY}px`
          );
        }
        element.style.setProperty(
          "--_page-shell-footer-row-height",
          `${element.dataset.footer === "row" && footer ? footer.getBoundingClientRect().height : 0}px`
        );
        const styles = getComputedStyle(element);
        const tracks = styles.gridTemplateColumns.split(" ").map(parseFloat);
        const minimumMainWidth = parseFloat(
          styles.getPropertyValue("--_page-shell-content-min-width")
        );
        const availableWidth =
          element.clientWidth - (tracks[1] || 0) - (tracks[4] || 0);
        const contextMaxWidth = Math.max(
          200,
          Math.min(1000, Math.floor(availableWidth - minimumMainWidth))
        );
        if (this.pageShell.contextMaxWidth !== contextMaxWidth) {
          this.pageShell.contextMaxWidth = contextMaxWidth;
        }
        const navigationMaxWidth = Math.max(
          PANEL_LIMITS.navigation.minWidth,
          Math.min(
            PANEL_LIMITS.navigation.maxWidth,
            Math.floor(
              element.clientWidth - (tracks[4] || 0) - minimumMainWidth
            )
          )
        );
        if (this.pageShell.navigationMaxWidth !== navigationMaxWidth) {
          this.pageShell.navigationMaxWidth = navigationMaxWidth;
        }
        const cannotOpenContext =
          availableWidth - PANEL_LIMITS.context.minWidth < minimumMainWidth;
        element.toggleAttribute(
          "data-constrained-context",
          element.dataset.context === "open" && cannotOpenContext
        );
        element.toggleAttribute("data-cannot-open-context", cannotOpenContext);
        const { left, right, width } = content.getBoundingClientRect();
        const inlineStart =
          styles.direction === "rtl"
            ? document.documentElement.clientWidth - right
            : left;
        if (headerStart) {
          element.style.setProperty(
            "--_page-shell-header-start-width",
            `${headerStart.getBoundingClientRect().width}px`
          );
        }
        if (headerEnd) {
          element.style.setProperty(
            "--_page-shell-header-end-width",
            `${headerEnd.getBoundingClientRect().width}px`
          );
        }
        if (headerStart && headerWrap && !this.site.mobileView) {
          // Keep the full logo's width while compact, so the narrower compact
          // logo cannot switch it back on. Layout sizes ignore transforms.
          if (
            !this.pageShell.compactLogo &&
            !headerStart.querySelector(".title--minimized")
          ) {
            fullHeaderStartWidth = headerStart.offsetWidth;
          }
          const compactLogo =
            !tracks[1] &&
            fullHeaderStartWidth +
              (headerEnd?.offsetWidth ?? 0) +
              parseFloat(
                styles.getPropertyValue("--_page-shell-header-main-min-width")
              ) >
              (element.dataset.contextPosition === "end"
                ? tracks[2] || 0
                : (tracks[3] || 0) + (tracks[4] || 0));
          if (this.pageShell.compactLogo !== compactLogo) {
            this.pageShell.compactLogo = compactLogo;
          }
        }
        element.style.setProperty(
          "--_page-shell-content-inline-start",
          `${inlineStart}px`
        );
        element.style.setProperty("--_page-shell-content-width", `${width}px`);
      });
    };

    const observer = new ResizeObserver(measure);
    // The content can move without changing size when a centered shell grows.
    observer.observe(element);
    observer.observe(content);
    for (const child of element.children) {
      observer.observe(child);
    }
    // Bars and notices before the shell can move it without resizing it.
    for (
      let sibling = element.previousElementSibling;
      sibling;
      sibling = sibling.previousElementSibling
    ) {
      observer.observe(sibling);
    }
    if (footer) {
      observer.observe(footer);
    }
    if (headerStart) {
      observer.observe(headerStart);
    }
    if (headerEnd) {
      observer.observe(headerEnd);
    }
    window.addEventListener("resize", measure);
    this.measure = measure;

    registerDestructor(this, () => {
      observer.disconnect();
      window.removeEventListener("resize", measure);
      cancelAnimationFrame(frame);
      this.pageShell.compactLogo = false;
      element.style.removeProperty("--_page-shell-document-offset");
      element.style.removeProperty("--_page-shell-body-offset");
      element.style.removeProperty("--_page-shell-footer-row-height");
      element.style.removeProperty("--_page-shell-content-inline-start");
      element.style.removeProperty("--_page-shell-content-width");
      element.style.removeProperty("--_page-shell-header-start-width");
      element.style.removeProperty("--_page-shell-header-end-width");
      element.style.removeProperty("--_page-shell-navigation-default-width");
      element.style.removeProperty("--_page-shell-context-default-width");
    });
  }
}
