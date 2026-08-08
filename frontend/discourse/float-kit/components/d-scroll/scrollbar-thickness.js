const measuredDocuments = new WeakMap();

export default function ensureScrollbarThickness(ownerDocument) {
  const body = ownerDocument?.body;
  if (!body) {
    return;
  }

  let thickness = measuredDocuments.get(ownerDocument);

  if (thickness === undefined) {
    const measurer = ownerDocument.createElement("div");
    measurer.setAttribute("data-d-scroll", "scrollbar-measurer");
    body.append(measurer);
    thickness = measurer.offsetWidth - measurer.clientWidth;
    measurer.remove();
    measuredDocuments.set(ownerDocument, thickness);
  }

  body.style.setProperty("--d-scroll-ua-scrollbar-thickness", `${thickness}px`);
}
