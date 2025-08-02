(function () {
  if (window.unsupportedBrowser) {
    throw "Unsupported browser detected";
  }

  let element = document.querySelector(
    `meta[name="discourse/config/environment"]`
  );
  const config = JSON.parse(
    decodeURIComponent(element.getAttribute("content"))
  );
  const event = new CustomEvent("discourse-init", { detail: config });
  document.dispatchEvent(event);
})();
