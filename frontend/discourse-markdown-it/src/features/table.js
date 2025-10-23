export function setup(helper) {
  helper.registerPlugin((md) => {
    md.renderer.rules.table_open = function () {
      return '<div class="md-table">\n<table>\n';
    };

    md.renderer.rules.table_close = function () {
      return "</table>\n</div>";
    };
  });

  // we need a custom callback for style handling
  helper.allowList({
    custom(tag, attr, val) {
      if (tag !== "th" && tag !== "td") {
        return false;
      }

      if (attr !== "style") {
        return false;
      }

      return (
        val === "text-align:right" ||
        val === "text-align:left" ||
        val === "text-align:center"
      );
    },
  });

  helper.allowList([
    "table",
    "tbody",
    "thead",
    "tr",
    "th",
    "th[colspan]",
    "th[rowspan]",
    "td",
    "td[colspan]",
    "td[rowspan]",
    "div.md-table",
  ]);
}
