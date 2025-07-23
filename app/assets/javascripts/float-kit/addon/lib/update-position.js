import {
  arrow,
  autoPlacement,
  computePosition,
  flip,
  hide,
  inline,
  limitShift,
  offset,
  shift,
} from "@floating-ui/dom";
import domFromString from "discourse/lib/dom-from-string";
import { isTesting } from "discourse/lib/environment";
import { iconHTML } from "discourse/lib/icon-library";
import { headerOffset } from "discourse/lib/offset-calculator";
import {
  FLOAT_UI_PLACEMENTS,
  PLACEMENT_STRATEGIES,
} from "float-kit/lib/constants";

const centerOffset = offset(({ rects }) => {
  return -rects.reference.height / 2 - rects.floating.height / 2;
});

export async function updatePosition(trigger, content, options) {
  const padding = options.padding ?? {
    top: headerOffset(),
    left: 10,
    right: 10,
    bottom: 10,
  };

  const detectOverflowOptions = {
    padding: isTesting() ? 0 : padding,
    boundary: options.boundary,
  };

  // Determine which placement middleware to use
  const placementStrategy =
    options.placementStrategy ?? PLACEMENT_STRATEGIES.FLIP;

  const placementStrategyMiddleware =
    placementStrategy === PLACEMENT_STRATEGIES.AUTO_PLACEMENT
      ? autoPlacement({
          allowedPlacements: options.allowedPlacements ?? FLOAT_UI_PLACEMENTS,
          ...detectOverflowOptions,
        })
      : flip({
          fallbackPlacements: options.fallbackPlacements ?? FLOAT_UI_PLACEMENTS,
          ...detectOverflowOptions,
        });

  const middleware = [];
  const isCentered = options.placement === "center";

  if (isCentered) {
    middleware.push(centerOffset);
  } else {
    middleware.push(offset(options.offset ?? 10));

    if (options.inline) {
      middleware.push(inline());
    }

    middleware.push(placementStrategyMiddleware);

    let limiter;
    if (options.limitShift) {
      limiter = limitShift(options.limitShift);
    }
    middleware.push(
      shift({
        padding: detectOverflowOptions.padding,
        limiter,
        crossAxis: true,
      })
    );
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

  if (options.hide) {
    middleware.push(hide({ padding: detectOverflowOptions.padding }));
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
      visibility: middlewareData.hide?.referenceHidden ? "hidden" : "visible",
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
