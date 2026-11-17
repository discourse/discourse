import { trustHTML } from "@ember/template";
import { helperContext } from "discourse/lib/helpers";
import { iconHTML } from "discourse/lib/icon-library";
import {
  APPROVED,
  DELETED,
  IGNORED,
  PENDING,
  REJECTED,
} from "discourse/models/reviewable";
import { i18n } from "discourse-i18n";

const STATUS_NAMES = {
  approved: {},
  rejected: {},
};

/**
 * Register a custom status name for a reviewable type.
 *
 * This allows plugins to customize the status badge text shown in the
 * review queue after an action is performed (e.g. "Tool approved" instead
 * of the default "Problem confirmed").
 *
 * @param {string} reviewableType - The reviewable class name (e.g. "ReviewableAiToolAction")
 * @param {string} approvedName - i18n key suffix for the approved status (looked up as `review.statuses.{name}.title`)
 * @param {string} rejectedName - i18n key suffix for the rejected status (looked up as `review.statuses.{name}.title`)
 */
export function registerReviewableStatusName(
  reviewableType,
  approvedName,
  rejectedName
) {
  STATUS_NAMES.approved[reviewableType] = approvedName;
  STATUS_NAMES.rejected[reviewableType] = rejectedName;
}

/**
 * Whether resolving a reviewable with this status confirmed a problem.
 * Approval-style reviewables confirm one by being rejected, and the rest by
 * being approved.
 *
 * @param {number} status - The reviewable's (or score's) resolved status
 * @param {boolean} approvalStyle - Whether approving means no problem was found
 * @returns {boolean | undefined} undefined when the status is neither approved nor rejected
 */
export function reviewableProblemConfirmed(status, approvalStyle) {
  if (status !== APPROVED && status !== REJECTED) {
    return;
  }
  return (status === APPROVED) !== Boolean(approvalStyle);
}

function registeredStatusName(status, type) {
  return (status === APPROVED ? STATUS_NAMES.approved : STATUS_NAMES.rejected)[
    type
  ];
}

/**
 * How an approved or rejected reviewable is shown: its status label, icon and
 * CSS modifier, and the timeline entry for whoever resolved it. With consistent
 * answers these describe whether a problem was confirmed; otherwise, or when
 * the reviewable isn't about a problem, they describe what was approved or
 * rejected.
 *
 * @param {number} status - The reviewable's (or score's) resolved status
 * @param {string} type - The reviewable class name
 * @param {boolean} approvalStyle - Whether approving means no problem was found
 * @param {boolean} [answersProblem=true] - Whether resolving the reviewable answers whether there's a problem
 * @returns {{ name: string, icon: string, cssClass: string, timelineKey: string } | undefined}
 *   undefined when the status is neither approved nor rejected
 */
export function reviewableOutcome(
  status,
  type,
  approvalStyle,
  answersProblem = true
) {
  const confirmed = reviewableProblemConfirmed(status, approvalStyle);
  if (confirmed === undefined) {
    return;
  }

  const approved = status === APPROVED;
  const registered = registeredStatusName(status, type);
  const genericTimelineKey = approved
    ? "review.timeline.approved_by"
    : "review.timeline.rejected_by";

  if (
    !answersProblem ||
    !helperContext().siteSettings.review_queue_consistent_answers
  ) {
    return {
      name: registered || legacyOutcomeName(approved, type, approvalStyle),
      icon: approved ? "check" : "xmark",
      cssClass: approved ? "approved" : "rejected",
      timelineKey: genericTimelineKey,
    };
  }

  let timelineKey = genericTimelineKey;
  if (!registered) {
    timelineKey = confirmed
      ? "review.timeline.problem_confirmed_by"
      : "review.timeline.no_problem_found_by";
  }

  return {
    name: registered || (confirmed ? "problem_confirmed" : "no_problem_found"),
    icon: confirmed ? "xmark" : "check",
    cssClass: confirmed ? "problem-confirmed" : "no-problem-found",
    timelineKey,
  };
}

// Names the item that was approved or rejected, as shown without consistent answers.
function legacyOutcomeName(approved, type, approvalStyle) {
  if (type === "ReviewableUser") {
    return approved ? "approved_user" : "rejected_user";
  } else if (approvalStyle) {
    return approved ? "approved_post" : "rejected_post";
  } else {
    return approved ? "approved_flag" : "rejected_flag";
  }
}

// Callers written before approval style was serialized only pass a type.
const LEGACY_APPROVAL_STYLE_TYPES = new Set([
  "ReviewableQueuedPost",
  "ReviewablePost",
  "ReviewableUser",
]);

function dataFor(
  status,
  type,
  approvalStyle = LEGACY_APPROVAL_STYLE_TYPES.has(type),
  answersProblem = true
) {
  switch (status) {
    case PENDING:
      return { name: "pending" };
    case APPROVED:
    case REJECTED: {
      const { name, icon, cssClass } = reviewableOutcome(
        status,
        type,
        approvalStyle,
        answersProblem
      );
      return { name, icon, cssClass };
    }
    case IGNORED:
      return {
        icon: "up-right-from-square",
        name: "ignored",
      };
    case DELETED:
      return { icon: "trash-can", name: "deleted" };
  }
}

/**
 * Returns a safe HTML string for a reviewable item status, given its status and type
 *
 * @param {number} status - The status of the reviewable item
 * @param {string} type - The type of the reviewable item
 * @param {boolean} [approvalStyle] - Whether approving the item means no problem was found; inferred from the type when omitted
 * @param {boolean} [answersProblem=true] - Whether resolving the item answers whether there's a problem
 * @returns {string} HTML for the reviewable item status
 */
export function newReviewableStatus(
  status,
  type,
  approvalStyle,
  answersProblem
) {
  let data = dataFor(status, type, approvalStyle, answersProblem);
  if (!data) {
    return;
  }

  const html = `
    <div class="review-item__status --${data.cssClass || data.name}">
      ${i18n("review.statuses." + data.name + ".title")}
    </div>
  `;

  return trustHTML(html);
}

export function htmlStatus(status, type, approvalStyle) {
  let data = dataFor(status, type, approvalStyle);
  if (!data) {
    return;
  }

  let icon = data.icon ? iconHTML(data.icon) : "";

  return `
    <span class="${data.cssClass || data.name}">
      ${icon}
      ${i18n("review.statuses." + data.name + ".title")}
    </span>
  `;
}

export default function (status, type, approvalStyle) {
  return trustHTML(htmlStatus(status, type, approvalStyle));
}
