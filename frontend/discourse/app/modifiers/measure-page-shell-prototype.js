import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";

export default class MeasurePageShellPrototype extends Modifier {
  modify(element, [, , , navigationWidth, contextWidth]) {
    element.style.setProperty(
      "--shell-prototype-navigation-width",
      `${navigationWidth}px`
    );
    element.style.setProperty(
      "--shell-prototype-context-width",
      `${contextWidth}px`
    );
    if (!this.measure) {
      this.setup(element);
    }
    this.measure?.();
  }

  setup(element) {
    const content = element.querySelector("#main-outlet");
    if (!content) {
      return;
    }
    const headerStart = element.querySelector(
      ".page-shell-prototype__header-start"
    );
    const headerEnd = element.querySelector(".d-header .contents > .panel");
    const body = element.querySelector("#main-outlet-wrapper");
    const footer = element.querySelector(".page-shell-prototype__footer");

    let frame;
    const measure = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        // Document offsets stay stable when a preceding bar scrolls away.
        element.style.setProperty(
          "--shell-prototype-document-offset",
          `${element.getBoundingClientRect().top + window.scrollY}px`
        );
        if (body) {
          element.style.setProperty(
            "--shell-prototype-body-offset",
            `${body.getBoundingClientRect().top + window.scrollY}px`
          );
        }
        element.style.setProperty(
          "--shell-prototype-footer-row-height",
          `${element.dataset.footer === "row" && footer ? footer.getBoundingClientRect().height : 0}px`
        );
        element.style.setProperty(
          "--shell-prototype-viewport-width",
          `${document.documentElement.clientWidth}px`
        );
        const styles = getComputedStyle(element);
        const tracks = styles.gridTemplateColumns.split(" ").map(parseFloat);
        const preferredContext =
          element.dataset.context === "open"
            ? parseFloat(
                styles.getPropertyValue("--shell-prototype-context-width")
              )
            : element.dataset.context === "rail"
              ? 56
              : 0;
        // Use viewport space, not the centered shell's current size: hiding a
        // track shrinks that shell and must not change the decision next frame.
        element.toggleAttribute(
          "data-constrained-context",
          document.documentElement.clientWidth -
            (tracks[0] || 0) -
            (tracks[2] || 0) -
            preferredContext <
            448
        );
        const { left, right, width } = content.getBoundingClientRect();
        const inlineStart =
          styles.direction === "rtl"
            ? document.documentElement.clientWidth - right
            : left;
        if (headerStart) {
          element.style.setProperty(
            "--shell-prototype-header-start-width",
            `${headerStart.getBoundingClientRect().width}px`
          );
        }
        if (headerEnd) {
          element.style.setProperty(
            "--shell-prototype-header-end-width",
            `${headerEnd.getBoundingClientRect().width}px`
          );
        }
        element.style.setProperty(
          "--shell-prototype-content-inline-start",
          `${inlineStart}px`
        );
        element.style.setProperty(
          "--shell-prototype-content-width",
          `${width}px`
        );
      });
    };

    const observer = new ResizeObserver(measure);
    // The content can move without changing size when a centered shell grows.
    observer.observe(element);
    observer.observe(content);
    for (const child of element.children) {
      observer.observe(child);
    }
    const controls = element.previousElementSibling;
    if (controls) {
      observer.observe(controls);
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
      element.style.removeProperty("--shell-prototype-viewport-width");
      element.style.removeProperty("--shell-prototype-document-offset");
      element.style.removeProperty("--shell-prototype-body-offset");
      element.style.removeProperty("--shell-prototype-footer-row-height");
      element.style.removeProperty("--shell-prototype-content-inline-start");
      element.style.removeProperty("--shell-prototype-content-width");
      element.style.removeProperty("--shell-prototype-header-start-width");
      element.style.removeProperty("--shell-prototype-header-end-width");
    });
  }
}
