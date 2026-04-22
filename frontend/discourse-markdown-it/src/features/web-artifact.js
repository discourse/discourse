export function setup(helper) {
  helper.allowList([
    "div[class=web-artifact]",
    "div[data-web-artifact-id]",
    "div[data-web-artifact-version]",
    "div[data-web-artifact-autorun]",
    "div[data-web-artifact-height]",
    "div[data-web-artifact-width]",
    "div[data-web-artifact-seamless]",
    // Backward compat with discourse-ai artifacts
    "div[class=ai-artifact]",
    "div[data-ai-artifact-id]",
    "div[data-ai-artifact-version]",
    "div[data-ai-artifact-autorun]",
    "div[data-ai-artifact-height]",
    "div[data-ai-artifact-width]",
  ]);
}
