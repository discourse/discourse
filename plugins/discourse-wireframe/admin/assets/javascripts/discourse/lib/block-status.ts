import { FAILURE_TYPE } from "discourse/lib/blocks/-internals/patterns";
import { i18n } from "discourse-i18n";
import { summarizeLeaf } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-summary";
import {
  type ConditionLeaf,
  isConditionTree,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";
import {
  childrenOf,
  combinatorOf,
  isGroup,
  isLeaf,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree-ops";

/** How the header strip tones a status. */
export type BlockStatusTone = "error" | "warning" | "muted";

/** One status a block's header strip can summarise. */
export type BlockStatus = {
  /** Stable identifier, exposed as `data-wf-status` for styling and tests. */
  id: string;
  /** Icon rendered before the label. */
  icon: string;
  /** Short translated label. */
  label: string;
  /** Longer explanation for the tooltip, when the label alone is terse. */
  title?: string;
  /** Visual tone. */
  tone: BlockStatusTone;
};

/** A condition leaf plus whether an enclosing `not` group negates it. */
type LeafRef = {
  /** The leaf condition. */
  leaf: ConditionLeaf;
  /** Whether the leaf is negated. */
  negated: boolean;
};

const STATUS_KEY = "wireframe.canvas.strip.status";

/**
 * The statuses a block's header strip summarises, most important first: a
 * render error, then any layout warning the chrome detected, then why a ghost
 * is hidden, then one entry per condition leaf that changes where or for whom
 * the block renders. The strip shows the first and lists the rest in its title.
 *
 * @param block - The block's ghost state, conditions, and chrome warnings.
 */
export function blockRenderStatuses({
  isGhost = false,
  isError = false,
  failureType,
  conditions,
  warnings = [],
}: {
  /** Whether the block is a ghost (failed / unknown entry). */
  isGhost?: boolean;
  /** Whether the ghost is a genuine authoring error. */
  isError?: boolean;
  /** Category of render failure for a ghost. */
  failureType?: string;
  /** The block's render conditions tree. */
  conditions?: unknown;
  /** Layout warnings the chrome detected. */
  warnings?: BlockStatus[];
}): BlockStatus[] {
  const statuses: BlockStatus[] = [];
  if (isError) {
    statuses.push({
      id: "error",
      icon: "triangle-exclamation",
      label: i18n(`${STATUS_KEY}.error`),
      tone: "error",
    });
  }
  statuses.push(...warnings);
  if (isGhost && !isError) {
    statuses.push(ghostStatus(failureType));
  }
  for (const { leaf, negated } of conditionLeaves(conditions)) {
    statuses.push(conditionStatus(leaf, negated));
  }
  return statuses;
}

/**
 * Why a non-error ghost renders nothing.
 *
 * @param failureType - Category of render failure.
 */
function ghostStatus(failureType: string | undefined): BlockStatus {
  switch (failureType) {
    case FAILURE_TYPE.NO_VISIBLE_CHILDREN:
      return {
        id: "no-visible-children",
        icon: "eye-slash",
        label: i18n(`${STATUS_KEY}.no_visible_children`),
        tone: "muted",
      };
    case FAILURE_TYPE.OPTIONAL_MISSING:
      return {
        id: "optional-missing",
        icon: "circle-question",
        label: i18n(`${STATUS_KEY}.optional_missing`),
        tone: "muted",
      };
    default:
      return {
        id: "hidden",
        icon: "eye-slash",
        label: i18n(`${STATUS_KEY}.hidden`),
        tone: "muted",
      };
  }
}

/**
 * Every leaf in a conditions tree, in document order, with its negation.
 *
 * @param tree - The block's conditions, in any accepted shape.
 */
function conditionLeaves(tree: unknown): LeafRef[] {
  if (!isConditionTree(tree) || tree == null) {
    return [];
  }
  const refs: LeafRef[] = [];
  const walk = (node: unknown, negated: boolean): void => {
    if (isLeaf(node)) {
      refs.push({ leaf: node, negated });
      return;
    }
    if (isGroup(node)) {
      const flips = combinatorOf(node) === "not";
      for (const child of childrenOf(node)) {
        walk(child, flips ? !negated : negated);
      }
    }
  };
  walk(tree, false);
  return refs;
}

/**
 * The strip status for one condition leaf.
 *
 * @param leaf - The leaf condition.
 * @param negated - Whether an enclosing `not` group negates it.
 */
function conditionStatus(leaf: ConditionLeaf, negated: boolean): BlockStatus {
  const summary = summarizeLeaf(leaf);
  let status: BlockStatus;
  switch (leaf.type) {
    case "viewport":
      status = viewportStatus(leaf, summary);
      break;
    case "user":
      status = userStatus(leaf, summary);
      break;
    case "route":
      status = muted("route", "link", i18n(`${STATUS_KEY}.route`, { summary }));
      break;
    case "setting":
      status = muted(
        "setting",
        "gear",
        i18n(`${STATUS_KEY}.setting`, { summary })
      );
      break;
    case "outlet-arg":
      status = muted(
        "outlet-arg",
        "code",
        i18n(`${STATUS_KEY}.outlet_arg`, { summary })
      );
      break;
    default:
      status = muted(
        "condition",
        "circle-question",
        i18n(`${STATUS_KEY}.condition`, { summary })
      );
  }
  if (negated) {
    return {
      ...status,
      label: i18n(`${STATUS_KEY}.negated`, { label: status.label }),
    };
  }
  return status;
}

/**
 * The strip status for a viewport condition: the editor's quick-pick ranges
 * get their own labels, anything else falls back to the condition summary.
 *
 * @param leaf - The viewport leaf.
 * @param summary - Its compact summary.
 */
function viewportStatus(leaf: ConditionLeaf, summary: string): BlockStatus {
  const { min, max, touch } = leaf;
  if (min === undefined && max === "sm") {
    return muted(
      "viewport",
      "mobile-screen",
      i18n(`${STATUS_KEY}.viewport_mobile`)
    );
  }
  if (min === "md" && max === undefined) {
    return muted(
      "viewport",
      "tablet-screen-button",
      i18n(`${STATUS_KEY}.viewport_tablet_up`)
    );
  }
  if (min === "lg" && max === undefined) {
    return muted(
      "viewport",
      "desktop",
      i18n(`${STATUS_KEY}.viewport_desktop_up`)
    );
  }
  if (min === undefined && max === undefined) {
    if (touch === true) {
      return muted(
        "viewport",
        "mobile-screen",
        i18n(`${STATUS_KEY}.touch_only`)
      );
    }
    if (touch === false) {
      return muted("viewport", "desktop", i18n(`${STATUS_KEY}.non_touch_only`));
    }
  }
  return muted(
    "viewport",
    max === undefined ? "desktop" : "mobile-screen",
    i18n(`${STATUS_KEY}.viewport`, { summary })
  );
}

/**
 * The strip status for a user condition.
 *
 * @param leaf - The user leaf.
 * @param summary - Its compact summary.
 */
function userStatus(leaf: ConditionLeaf, summary: string): BlockStatus {
  if (leaf.staff === true || leaf.admin === true || leaf.moderator === true) {
    return muted("user", "users", i18n(`${STATUS_KEY}.staff_only`));
  }
  const onlyLoggedIn = Object.keys(leaf).every(
    (key) => key === "type" || key === "loggedIn"
  );
  if (onlyLoggedIn && leaf.loggedIn === true) {
    return muted("user", "user", i18n(`${STATUS_KEY}.logged_in_only`));
  }
  if (onlyLoggedIn && leaf.loggedIn === false) {
    return muted("user", "user", i18n(`${STATUS_KEY}.anonymous_only`));
  }
  return muted("user", "users", i18n(`${STATUS_KEY}.user`, { summary }));
}

/**
 * Builds a muted (informational) status.
 *
 * @param id - Stable status identifier.
 * @param icon - Icon rendered before the label.
 * @param label - Translated label.
 */
function muted(id: string, icon: string, label: string): BlockStatus {
  return { id, icon, label, tone: "muted" };
}
