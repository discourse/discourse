import { modifier } from "ember-modifier";

export default modifier((element) => {
  const formElement = element.parentElement;
  if (!formElement) {
    return;
  }

  const resize = () => {
    const { width } = formElement.getBoundingClientRect();
    const { height } = element.getBoundingClientRect();
    element.style.width = `${width}px`;
    formElement.style.setProperty("--ai-agent-actions-height", `${height}px`);
  };

  resize();
  const resizeObserver = new ResizeObserver(resize);
  resizeObserver.observe(formElement);
  resizeObserver.observe(element);

  return () => {
    resizeObserver.disconnect();
    element.style.removeProperty("width");
    formElement.style.removeProperty("--ai-agent-actions-height");
  };
});
