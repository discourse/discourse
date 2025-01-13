import {
  arrow,
  computePosition,
  flip,
  inline,
  offset,
  shift,
} from "@floating-ui/dom";
import domFromString from "discourse/lib/dom-from-string";
import { isTesting } from "discourse/lib/environment";
import { iconHTML } from "discourse/lib/icon-library";
import { headerOffset } from "discourse/lib/offset-calculator";
import { FLOAT_UI_PLACEMENTS } from "float-kit/lib/constants";

const centerOffset = offset(({ rects }) => {
  return -rects.reference.height / 2 - rects.floating.height / 2;
});

export async function updatePosition(trigger, content, options) {
  let padding = 0;
  if (!isTesting()) {
    padding = options.padding || {
      top: headerOffset(),
      left: 10,
      right: 10,
      bottom: 10,
    };
  }

  const flipOptions = {
    fallbackPlacements: options.fallbackPlacements ?? FLOAT_UI_PLACEMENTS,
    padding,
  };

  const middleware = [];
  const isCentered = options.placement === "center";

  if (isCentered) {
    middleware.push(centerOffset);
  } else {
    middleware.push(offset(options.offset ? parseInt(options.offset, 10) : 10));

    if (options.inline) {
      middleware.push(inline());
    }

    middleware.push(flip(flipOptions));
    middleware.push(shift({ padding }));
  }

  let arrowElement;
  if (options.arrow) {
    arrowElement = content.querySelector(".arrow");

    if (!arrowElement) {
      arrowElement = domFromString(
        iconHTML("tippy-rounded-arrow", { class: "arrow" })
      )[0];
      content.appendChild(arrowElement);
    }

    middleware.push(arrow({ element: arrowElement }));
  }

  content.dataset.strategy = options.strategy || "absolute";

  const { x, y, placement, middlewareData } = await computePosition(
    trigger,
    content,
    {
      placement: isCentered ? "bottom" : options.placement,
      strategy: options.strategy || "absolute",
      middleware,
    }
  );

  if (options.computePosition) {
    options.computePosition(content, {
      x,
      y,
      placement,
      middlewareData,
      arrowElement,
    });
  } else {
    content.dataset.placement = placement;
    Object.assign(content.style, {
      left: `${x}px`,
      top: `${y}px`,
    });

    if (middlewareData.arrow && arrowElement) {
      const arrowX = middlewareData.arrow.x;
      const arrowY = middlewareData.arrow.y;

      Object.assign(arrowElement.style, {
        left: arrowX != null ? `${arrowX}px` : "",
        top: arrowY != null ? `${arrowY}px` : "",
      });
    }
  }
}
