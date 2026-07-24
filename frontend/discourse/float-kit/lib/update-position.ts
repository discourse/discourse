import {
  arrow,
  autoPlacement,
  type AutoUpdateOptions,
  type Boundary,
  computePosition,
  type ComputePositionReturn,
  flip,
  hide,
  inline,
  limitShift,
  type MiddlewareState,
  offset,
  type Padding,
  type Placement,
  shift,
  size,
  type Strategy,
} from "@floating-ui/dom";
import {
  FLOAT_UI_PLACEMENTS,
  type FloatKitTrigger,
  type FloatUiPlacement,
  VISIBILITY_OPTIMIZERS,
  type VisibilityOptimizer,
} from "discourse/float-kit/lib/constants";
import domFromString from "discourse/lib/dom-from-string";
import { isTesting } from "discourse/lib/environment";
import { iconHTML } from "discourse/lib/icon-library";
import { headerOffset } from "discourse/lib/offset-calculator";

/**
 * The positioning-related subset of a float's options that `updatePosition` reads.
 * Menu/tooltip instances pass their full options bag here; every field is optional
 * because programmatic callers supply only the ones they need and the rest fall back
 * to floating-ui defaults. `placement` additionally accepts the sentinel `"center"`,
 * which centers the float over its trigger instead of anchoring to an edge.
 */
export interface PositioningOptions {
  placement?: FloatUiPlacement | "center";
  strategy?: Strategy;
  autoUpdate?: boolean | AutoUpdateOptions;
  offset?: number;
  inline?: boolean | null;
  arrow?: boolean;
  hide?: boolean;
  padding?: Padding;
  boundary?: Boundary;
  visibilityOptimizer?: VisibilityOptimizer;
  shiftBeforeVisibilityOptimizer?: boolean;
  allowedPlacements?: readonly FloatUiPlacement[];
  fallbackPlacements?: readonly FloatUiPlacement[];
  limitShift?: Parameters<typeof limitShift>[0];
  crossAxisShift?: boolean;
  matchTriggerWidth?: boolean;
  matchTriggerMinWidth?: boolean;
  constrainHeightToViewport?: boolean;
  minHeight?: number;
  computePosition?: (
    content: HTMLElement,
    result: ComputePositionReturn & { arrowElement?: HTMLElement }
  ) => void;
}

interface DetectOverflowOptions {
  padding: Padding;
  boundary?: Boundary;
}

/** The state floating-ui hands to a `size` middleware's `apply` callback. */
type SizeApplyState = MiddlewareState & {
  availableWidth: number;
  availableHeight: number;
};

const centerOffset = offset(({ rects }) => {
  return -rects.reference.height / 2 - rects.floating.height / 2;
});

export async function updatePosition(
  trigger: FloatKitTrigger,
  content: HTMLElement,
  options: PositioningOptions
): Promise<void> {
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
    // `options.placement` may be the `"center"` sentinel, but that path is handled
    // by `centered` above, so anything reaching floating-ui is a real placement.
    placement: (centered ? "bottom" : options.placement) as Placement,
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

function buildMiddleware(
  options: PositioningOptions,
  content: HTMLElement,
  detectOverflowOptions: DetectOverflowOptions
) {
  const middleware = [];
  const centered = isCenteredPlacement(options);

  if (centered) {
    middleware.push(centerOffset);
  } else {
    middleware.push(offset(options.offset ?? 10));

    if (options.inline) {
      middleware.push(inline());
    }

    const shiftMiddleware = buildShiftMiddleware(
      options,
      detectOverflowOptions
    );
    const visibilityOptimizer = buildVisibilityOptimizerMiddleware(
      options,
      detectOverflowOptions
    );

    if (!visibilityOptimizer) {
      middleware.push(shiftMiddleware);
    } else if (options.shiftBeforeVisibilityOptimizer) {
      middleware.push(shiftMiddleware, visibilityOptimizer);
    } else {
      middleware.push(visibilityOptimizer, shiftMiddleware);
    }
  }

  let arrowElement: HTMLElement | undefined;
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

function applyComputedPosition(
  content: HTMLElement,
  result: ComputePositionReturn,
  arrowElement: HTMLElement | undefined
) {
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

function getPadding(options: PositioningOptions): Padding {
  return (
    options.padding ?? {
      top: headerOffset(),
      left: 10,
      right: 10,
      bottom: 10,
    }
  );
}

function buildDetectOverflowOptions(
  options: PositioningOptions,
  padding: Padding
): DetectOverflowOptions {
  return {
    padding: isTesting() ? 0 : padding,
    boundary: options.boundary,
  };
}

function isCenteredPlacement(options: PositioningOptions): boolean {
  return options.placement === "center";
}

function ensureArrowElement(content: HTMLElement): HTMLElement {
  let arrowElement = content.querySelector<HTMLElement>(".arrow");
  if (!arrowElement) {
    arrowElement = domFromString(
      iconHTML("tippy-rounded-arrow", { class: "arrow" })
    )[0] as HTMLElement;
    content.appendChild(arrowElement);
  }
  return arrowElement;
}

function buildVisibilityOptimizerMiddleware(
  options: PositioningOptions,
  detectOverflowOptions: DetectOverflowOptions
) {
  const visibilityOptimizer =
    options.visibilityOptimizer ?? VISIBILITY_OPTIMIZERS.FLIP;

  if (visibilityOptimizer === VISIBILITY_OPTIMIZERS.NONE) {
    return null;
  }

  if (visibilityOptimizer === VISIBILITY_OPTIMIZERS.AUTO_PLACEMENT) {
    return autoPlacement({
      allowedPlacements: (options.allowedPlacements ??
        FLOAT_UI_PLACEMENTS) as Placement[],
      ...detectOverflowOptions,
    });
  }

  return flip({
    fallbackPlacements: (options.fallbackPlacements ??
      FLOAT_UI_PLACEMENTS) as Placement[],
    ...detectOverflowOptions,
  });
}

function buildShiftMiddleware(
  options: PositioningOptions,
  detectOverflowOptions: DetectOverflowOptions
) {
  let limiter: ReturnType<typeof limitShift> | undefined;
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

function buildMatchSizeMiddleware(options: PositioningOptions) {
  if (options.matchTriggerWidth || options.matchTriggerMinWidth) {
    return size({
      apply({ rects, elements }: SizeApplyState) {
        const styleProps: Record<string, string> = {};
        const widthValue = `${rects.reference.width}px`;

        if (options.matchTriggerWidth) {
          styleProps.width = widthValue;
        }

        if (options.matchTriggerMinWidth) {
          styleProps.minWidth = widthValue;
        }

        Object.assign(elements.floating.style, styleProps);
      },
    });
  }

  return null;
}

function buildConstrainHeightMiddleware(
  options: PositioningOptions,
  detectOverflowOptions: DetectOverflowOptions
) {
  if (!options.constrainHeightToViewport) {
    return null;
  }

  return size({
    apply({ availableHeight, elements }: SizeApplyState) {
      const max = Math.max(50, (availableHeight ?? 0) - 4);
      const inner = elements.floating.querySelector<HTMLElement>(
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
