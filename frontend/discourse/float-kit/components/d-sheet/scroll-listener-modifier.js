import { modifier } from "ember-modifier";

export default modifier((element, [handler, isScrollOngoing]) => {
  if (!isScrollOngoing) {
    return;
  }
  let rafId = null;
  function loop() {
    handler();
    rafId = requestAnimationFrame(loop);
  }

  loop();
  return () => {
    if (rafId !== null) {
      cancelAnimationFrame(rafId);
    }
  };
});
