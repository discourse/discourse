export function setup(helper) {
  helper.allowList([
    "div[class=web-artifact]",
    "div[data-web-artifact-id]",
    "div[data-web-artifact-version]",
    "div[data-web-artifact-autorun]",
    "div[data-web-artifact-height]",
    "div[data-web-artifact-width]",
    "div[data-web-artifact-seamless]",
  ]);
}
