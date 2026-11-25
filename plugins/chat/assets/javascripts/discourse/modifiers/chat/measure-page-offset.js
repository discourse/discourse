import { modifier } from "ember-modifier";

export default modifier((element) => {
  const shell = element.closest(".page-shell");
  if (!shell) {
    return;
  }

  const footer = shell.querySelector(".page-shell__footer");
  let frame;
  const measure = () => {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => {
      const top = element.getBoundingClientRect().top + window.scrollY;
      const footerHeight = footer?.getBoundingClientRect().height ?? 0;
      element.style.setProperty(
        "--_chat-page-offset",
        `${top + footerHeight}px`
      );
    });
  };

  const observer = new ResizeObserver(measure);
  for (let node = element; node; node = node.parentElement) {
    observer.observe(node);
    for (
      let sibling = node.previousElementSibling;
      sibling;
      sibling = sibling.previousElementSibling
    ) {
      observer.observe(sibling);
    }
    if (node === shell) {
      break;
    }
  }
  if (footer) {
    observer.observe(footer);
  }
  measure();

  return () => {
    observer.disconnect();
    cancelAnimationFrame(frame);
    element.style.removeProperty("--_chat-page-offset");
  };
});
