// discourse-skip-module
function exists(selector) {
  return count(selector) > 0;
}

function count(selector) {
  return find(selector).length;
}

function visible(selector) {
  return find(selector + ":visible").length > 0;
}

function invisible(selector) {
  const $items = find(selector + ":visible");
  return (
    $items.length === 0 ||
    $items.css("opacity") !== "1" ||
    $items.css("visibility") === "hidden"
  );
}
