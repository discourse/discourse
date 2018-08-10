 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
/* exported exists, count, present, blank, containsInstance, not, visible, invisible */

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
  var $items = find(selector + ":visible");
  return $items.length === 0 ||
         $items.css("opacity") === "0" ||
         $items.css("visibility") === "hidden";
}
//@license-end
