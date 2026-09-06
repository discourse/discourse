export function setup(helper) {
  // The mount point is an empty <div> keyed only by the reviewable id; the
  // AiToolApproval card component (which owns the `.ai-tool-approval` class) is
  // rendered into it client-side, so only the data attribute needs allow-listing.
  helper.allowList(["div[data-ai-tool-approval-reviewable-id]"]);
}
