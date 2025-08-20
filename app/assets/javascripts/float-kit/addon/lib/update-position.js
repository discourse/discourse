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
  size,
} from "@floating-ui/dom";
import domFromString from "discourse/lib/dom-from-string";
import { isTesting } from "discourse/lib/environment";
import { iconHTML } from "discourse/lib/icon-library";
import { headerOffset } from "discourse/lib/offset-calculator";
import {
  FLOAT_UI_PLACEMENTS,
  VISIBILITY_OPTIMIZERS,
} from "float-kit/lib/constants";

const centerOffset = offset(({ rects }) => {
  return -rects.reference.height / 2 - rects.floating.height / 2;
});

export async function updatePosition(trigger, content, options) {
  const padding = getPadding(options);
  const detectOverflowOptions = buildDetectOverflowOptions(options, padding);
  const centered = isCenteredPlacement(options);

  const { middleware, arrowElement } = buildMiddleware(
    options,
    content,
    detectOverflowOptions
  );

  content.dataset.strategy = options.strategy || "absolute";

  const result = await computePosition(trigger, content, {
    placement: centered ? "bottom" : options.placement,
    strategy: options.strategy || "absolute",
    middleware,
  });

  if (options.computePosition) {
    options.computePosition(content, {
      ...result,
      arrowElement,
    });
  } else {
    applyComputedPosition(content, result, arrowElement);
  }
}

function buildMiddleware(options, content, detectOverflowOptions) {
  const middleware = [];
  const centered = isCenteredPlacement(options);

  if (centered) {
    middleware.push(centerOffset);
  } else {
    middleware.push(offset(options.offset ?? 10));

    if (options.inline) {
      middleware.push(inline());
    }

    const visibilityOptimizer = buildVisibilityOptimizerMiddleware(
      options,
      detectOverflowOptions
    );
    if (visibilityOptimizer) {
      middleware.push(visibilityOptimizer);
    }

    middleware.push(buildShiftMiddleware(options, detectOverflowOptions));
  }

  let arrowElement;
  if (options.arrow) {
    arrowElement = ensureArrowElement(content);
    middleware.push(arrow({ element: arrowElement }));
  }

  if (options.hide) {
    middleware.push(hide({ padding: detectOverflowOptions.padding }));
  }

  const matchSize = buildMatchSizeMiddleware(options);
  if (matchSize) {
    middleware.push(matchSize);
  }

  const constrainHeight = buildConstrainHeightMiddleware(
    options,
    detectOverflowOptions
  );
  if (constrainHeight) {
    middleware.push(constrainHeight);
  }

  return { middleware, arrowElement };
}

function applyComputedPosition(content, result, arrowElement) {
  const { x, y, placement, middlewareData } = result;

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

function getPadding(options) {
  return (
    options.padding ?? {
      top: headerOffset(),
      left: 10,
      right: 10,
      bottom: 10,
    }
  );
}

function buildDetectOverflowOptions(options, padding) {
  return {
    padding: isTesting() ? 0 : padding,
    boundary: options.boundary,
  };
}

function isCenteredPlacement(options) {
  return options.placement === "center";
}

function ensureArrowElement(content) {
  let arrowElement = content.querySelector(".arrow");
  if (!arrowElement) {
    arrowElement = domFromString(
      iconHTML("tippy-rounded-arrow", { class: "arrow" })
    )[0];
    content.appendChild(arrowElement);
  }
  return arrowElement;
}

function buildVisibilityOptimizerMiddleware(options, detectOverflowOptions) {
  const visibilityOptimizer =
    options.visibilityOptimizer ?? VISIBILITY_OPTIMIZERS.FLIP;

  if (visibilityOptimizer === VISIBILITY_OPTIMIZERS.NONE) {
    return null;
  }

  if (visibilityOptimizer === VISIBILITY_OPTIMIZERS.AUTO_PLACEMENT) {
    return autoPlacement({
      allowedPlacements: options.allowedPlacements ?? FLOAT_UI_PLACEMENTS,
      ...detectOverflowOptions,
    });
  }

  return flip({
    fallbackPlacements: options.fallbackPlacements ?? FLOAT_UI_PLACEMENTS,
    ...detectOverflowOptions,
  });
}

function buildShiftMiddleware(options, detectOverflowOptions) {
  let limiter;
  if (options.limitShift) {
    limiter = limitShift(options.limitShift);
  }

  const crossAxis = options.crossAxisShift ?? true;

  return shift({
    padding: detectOverflowOptions.padding,
    limiter,
    crossAxis,
  });
}

function buildMatchSizeMiddleware(options) {
  if (options.matchTriggerWidth) {
    return size({
      apply({ rects, elements }) {
        Object.assign(elements.floating.style, {
          width: `${rects.reference.width}px`,
        });
      },
    });
  }

  if (options.matchTriggerMinWidth) {
    return size({
      apply({ rects, elements }) {
        Object.assign(elements.floating.style, {
          minWidth: `${rects.reference.width}px`,
        });
      },
    });
  }

  return null;
}

function buildConstrainHeightMiddleware(options, detectOverflowOptions) {
  if (!options.constrainHeightToViewport) {
    return null;
  }

  return size({
    apply({ availableHeight, elements }) {
      const max = Math.max(50, (availableHeight ?? 0) - 4);
      const inner = elements.floating.querySelector(
        ".fk-d-menu__inner-content"
      );

      const hideElement =
        options.minHeight && availableHeight < options.minHeight;

      if (inner) {
        inner.style.display = hideElement ? "none" : "";
        Object.assign(inner.style, { maxHeight: `${max}px` });
      } else {
        elements.floating.style.display = hideElement ? "none" : "";
        Object.assign(elements.floating.style, {
          maxHeight: `${max}px`,
          overflow: "auto",
        });
      }
    },
    ...detectOverflowOptions,
  });
}
