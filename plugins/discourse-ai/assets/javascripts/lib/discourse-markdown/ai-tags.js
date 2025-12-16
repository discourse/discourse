export function setup(helper) {
  helper.allowList(["details[class=ai-quote]", "details[class=ai-thinking]"]);
  helper.allowList([
    "div[class=ai-artifact]",
    "div[data-ai-artifact-id]",
    "div[data-ai-artifact-version]",
    "div[data-ai-artifact-autorun]",
    "div[data-ai-artifact-height]",
    "div[data-ai-artifact-width]",
  ]);
}
