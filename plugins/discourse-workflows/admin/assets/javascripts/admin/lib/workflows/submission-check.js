export const SUBMISSION_TRIGGER_TYPE = "trigger:before_post_submission";
export const SUBMISSION_REJECT_TYPE = "action:reject_submission";

export function isSubmissionWorkflow(nodes) {
  return (nodes || []).some(
    (node) =>
      node.type === SUBMISSION_TRIGGER_TYPE ||
      node.type === SUBMISSION_REJECT_TYPE
  );
}
