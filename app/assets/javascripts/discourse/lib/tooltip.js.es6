import deprecated from "discourse-common/lib/deprecated";
import { escapeExpression } from "discourse/lib/utilities";

const fadeSpeed = 300;
const tooltipID = "#discourse-tooltip";

export function showTooltip(e) {
  const $this = $(e.currentTarget),
    $parent = $this.offsetParent();
  // html tooltip are risky try your best to sanitize anything
  // displayed as html to avoid XSS attacks
  const content = $this.attr("data-tooltip")
    ? escapeExpression($this.attr("data-tooltip"))
    : $this.attr("data-html-tooltip") || "";
  const retina =
    window.devicePixelRatio && window.devicePixelRatio > 1
      ? "class='retina'"
      : "";

  let pos = $this.offset();
  const delta = $parent.offset();
  pos.top -= delta.top;
  pos.left -= delta.left;

  hideTooltip(tooltipID);

  $this.after(`
    <div id="discourse-tooltip" ${retina}>
      <div class="tooltip-pointer"></div>
      <div class="tooltip-content">${content}</div>
    </div>
  `);

  $(window).on("click.discourse", event => {
    if ($(event.target).closest(tooltipID).length === 0) {
      $(tooltipID).remove();
      $(window).off("click.discourse");
    }
    return true;
  });

  const $tooltip = $(tooltipID);
  $tooltip.css({ top: 0, left: 0 });

  let left = pos.left - $tooltip.width() / 2 + $this.width() / 2;
  if (left < 0) {
    $tooltip.find(".tooltip-pointer").css({
      "margin-left": left * 2 + "px"
    });
    left = 0;
  }

  // also do a right margin fix
  const parentWidth = $parent.width();
  if (left + $tooltip.width() > parentWidth) {
    let oldLeft = left;
    left = parentWidth - $tooltip.width();

    $tooltip.find(".tooltip-pointer").css({
      "margin-left": (oldLeft - left) * 2 + "px"
    });
  }

  $tooltip.css({
    top: pos.top + 5 + "px",
    left: left + "px"
  });

  $tooltip.fadeIn(fadeSpeed);

  return false;
}

export function hideTooltip() {
  $(tooltipID)
    .fadeOut(fadeSpeed)
    .remove();
}

export function registerTooltip(jqueryContext) {
  deprecated("tooltip is getting deprecated. Use d-popover instead");

  if (jqueryContext.length) {
    jqueryContext.off("click").on("click", event => showTooltip(event));
  }
}

export function registerHoverTooltip(jqueryContext) {
  deprecated("tooltip is getting deprecated. Use d-popover instead");

  if (jqueryContext.length) {
    jqueryContext
      .off("mouseenter mouseleave click")
      .on("mouseenter click", showTooltip)
      .on("mouseleave", hideTooltip);
  }
}

export function unregisterTooltip(jqueryContext) {
  if (jqueryContext.length) {
    jqueryContext.off("click");
  }
}

export function unregisterHoverTooltip(jqueryContext) {
  if (jqueryContext.length) {
    jqueryContext.off("mouseenter mouseleave click");
  }
}
