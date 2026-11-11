import { modifier } from "ember-modifier";

export default modifier((element) => {
  const content = element.querySelector("#main-outlet");
  if (!content) {
    return;
  }
  const headerStart = element.querySelector(
    ".page-shell-prototype__header-start"
  );
  const headerEnd = element.querySelector(".d-header .contents > .panel");

  let frame;
  const measure = () => {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => {
      const styles = getComputedStyle(element);
      const tracks = styles.gridTemplateColumns.split(" ").map(parseFloat);
      const preferredRight =
        element.dataset.right === "open"
          ? parseFloat(styles.getPropertyValue("--shell-prototype-right-width"))
          : element.dataset.right === "rail"
            ? 56
            : 0;
      // Use viewport space, not the centered shell's current size: hiding a
      // track shrinks that shell and must not change the decision next frame.
      element.toggleAttribute(
        "data-constrained-right",
        document.documentElement.clientWidth -
          (tracks[0] || 0) -
          (tracks[2] || 0) -
          preferredRight <
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
  if (headerStart) {
    observer.observe(headerStart);
  }
  if (headerEnd) {
    observer.observe(headerEnd);
  }
  window.addEventListener("resize", measure);
  measure();

  return () => {
    observer.disconnect();
    window.removeEventListener("resize", measure);
    cancelAnimationFrame(frame);
    element.style.removeProperty("--shell-prototype-content-inline-start");
    element.style.removeProperty("--shell-prototype-content-width");
    element.style.removeProperty("--shell-prototype-header-start-width");
    element.style.removeProperty("--shell-prototype-header-end-width");
  };
});
