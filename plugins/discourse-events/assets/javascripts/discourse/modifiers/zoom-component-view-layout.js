import { modifier } from "ember-modifier";
import {
  isZoomLeaveButtonClick,
  syncZoomLayout,
} from "../lib/zoom-component-view-dom";

// Applied to the element the Zoom embedded SDK renders its component view
// into.
// Registers the element with the session and keeps Zoom's DOM in shape as it
// mutates and resizes.
export default modifier((element, [session, observeResize]) => {
  session.registerRoot(element);

  // Zoom's "meeting has not started" panel has its own leave button, and
  // unlike every other leave path it fires no `connection-change` event: the
  // SDK only reports `Closed` once it has a meeting id, which a join that
  // failed before the host started never gets. Watching the click is the only
  // signal.
  const onClick = (event) => {
    // The joined toolbar's leave button carries the same title, but clicking
    // it only opens Zoom's confirmation popper. Hiding the frame there would
    // strand the user in a meeting they can no longer see or leave. That path
    // reports `Closed` on its own once the user confirms.
    if (!session.isJoined && isZoomLeaveButtonClick(event)) {
      session.leaveZoom();
    }
  };
  element.addEventListener("click", onClick, { capture: true });

  let resizeObserver;
  if (observeResize && window.ResizeObserver) {
    resizeObserver = new ResizeObserver(() => {
      session.syncVideoSize();
      syncZoomLayout(element);
    });
    resizeObserver.observe(element);
  }

  let mutationObserver;
  if (window.MutationObserver) {
    mutationObserver = new MutationObserver(() => {
      syncZoomLayout(element);
    });
    mutationObserver.observe(element, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["style", "class"],
    });
  }

  syncZoomLayout(element);

  return () => {
    resizeObserver?.disconnect();
    mutationObserver?.disconnect();
    element.removeEventListener("click", onClick, { capture: true });
    session.unregisterRoot(element);
  };
});
