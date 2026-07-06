export function setup(helper) {
  helper.allowList([
    "div[class=ai-tool-approval]",
    "div[data-ai-tool-approval-reviewable-id]",
  ]);
}
