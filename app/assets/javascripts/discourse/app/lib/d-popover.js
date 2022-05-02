import { isLegacyEmber } from "discourse-common/config/environment";
import { run } from "@ember/runloop";
import tippy from "tippy.js";
import { iconHTML } from "discourse-common/lib/icon-library";

export function hidePopover(event) {
  if (event?.target?._tippy) {
    showPopover(event);
  }
}

// options accepts all tippy.js options as defined in their documentation
// https://atomiks.github.io/tippyjs/v6/all-props/
export function showPopover(event, options = {}) {
  const tippyOptions = Object.assign(
    {
      arrow: iconHTML("tippy-rounded-arrow"),
      content: options.textContent || options.htmlContent,
      allowHTML: options?.htmlContent?.length,
      trigger: "mouseenter click",
      hideOnClick: true,
      zIndex: 1400,
    },
    options
  );

  // legacy support
  delete tippyOptions.textContent;
  delete tippyOptions.htmlContent;

  const instance = event.target._tippy
    ? event.target._tippy
    : tippy(event.target, tippyOptions);

  // hangs on legacy ember
  if (!isLegacyEmber) {
    run.begin();
    instance.popper.addEventListener("transitionend", run.end, {
      once: true,
    });
  }

  if (instance.state.isShown) {
    instance.hide();
  } else {
    instance.show();
  }
}
