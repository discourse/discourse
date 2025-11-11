// On WebKit-based browsers, triple clicking on the last paragraph of a post won't stop at the end of the paragraph.
// It looks like the browser is selecting EOL characters, and that causes the selection to leak into the following
// nodes until it finds a non-empty node. This is a workaround to prevent that from happening.
// We insert a div after the last paragraph at the end of the cooked content, containing a <br> element.
// The line break works as a barrier, causing the selection to stop at the correct place.
// To prevent layout shifts this div is styled to be invisible with height 0 and overflow hidden and set aria-hidden
// to true to prevent screen readers from reading it.
export default function (element) {
  const selectionBarrier = document.createElement("div");
  selectionBarrier.classList.add("cooked-selection-barrier");
  selectionBarrier.ariaHidden = "true";
  selectionBarrier.appendChild(document.createElement("br"));
  element.appendChild(selectionBarrier);
}
