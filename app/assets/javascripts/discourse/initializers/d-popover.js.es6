import { showPopover, hidePopover } from "discourse/lib/d-popover";

const SELECTORS =
  "[data-html-popover],[data-tooltip],[data-popover],[data-html-tooltip]";

export default {
  name: "d-popover",

  initialize(container) {
    const router = container.lookup("router:main");
    router.on("routeWillChange", hidePopover);

    $("#main").on("click.d-popover mouseenter.d-popover", SELECTORS, event =>
      showPopover(event)
    );

    $("#main").on("mouseleave.d-popover", SELECTORS, event =>
      hidePopover(event)
    );
  }
};
