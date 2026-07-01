import { modifier } from "ember-modifier";

export default modifier((element, [handler, isScrollOngoing]) => {
  if (!isScrollOngoing) {
    return;
  }
  let rafId;
  function loop() {
    handler();
    rafId = requestAnimationFrame(loop);
  }

  loop();
  return () => {
    if (rafId) {
      cancelAnimationFrame(rafId);
    }
  };
});
