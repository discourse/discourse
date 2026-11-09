import { trustHTML } from "@ember/template";
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
 * Names the outcome of an approved or rejected reviewable as an i18n key
 * suffix: "problem_confirmed", "no_problem_found", or a name a plugin
 * registered for its type.
 *
 * @param {number} status - The reviewable's (or score's) resolved status
 * @param {string} type - The reviewable class name
 * @param {boolean} approvalStyle - Whether approving means no problem was found
 * @returns {string | undefined} undefined when the status is neither approved nor rejected
 */
export function reviewableOutcomeName(status, type, approvalStyle) {
  const confirmed = reviewableProblemConfirmed(status, approvalStyle);
  if (confirmed === undefined) {
    return;
  }

  return (
    registeredStatusName(status, type) ||
    (confirmed ? "problem_confirmed" : "no_problem_found")
  );
}

/**
 * The i18n key for the timeline entry recording who approved or rejected a
 * reviewable, worded to match its status label.
 *
 * @param {number} status - The reviewable's (or score's) resolved status
 * @param {string} type - The reviewable class name
 * @param {boolean} approvalStyle - Whether approving means no problem was found
 * @returns {string | undefined}
 */
export function reviewableOutcomeTimelineKey(status, type, approvalStyle) {
  const confirmed = reviewableProblemConfirmed(status, approvalStyle);
  if (confirmed === undefined) {
    return;
  }

  if (registeredStatusName(status, type)) {
    return status === APPROVED
      ? "review.timeline.approved_by"
      : "review.timeline.rejected_by";
  }
  return confirmed
    ? "review.timeline.problem_confirmed_by"
    : "review.timeline.no_problem_found_by";
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
  approvalStyle = LEGACY_APPROVAL_STYLE_TYPES.has(type)
) {
  switch (status) {
    case PENDING:
      return { name: "pending" };
    case APPROVED:
    case REJECTED: {
      const confirmed = reviewableProblemConfirmed(status, approvalStyle);
      return {
        icon: confirmed ? "xmark" : "check",
        name: reviewableOutcomeName(status, type, approvalStyle),
        cssClass: confirmed ? "problem-confirmed" : "no-problem-found",
      };
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
 * @returns {string} HTML for the reviewable item status
 */
export function newReviewableStatus(status, type, approvalStyle) {
  let data = dataFor(status, type, approvalStyle);
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
