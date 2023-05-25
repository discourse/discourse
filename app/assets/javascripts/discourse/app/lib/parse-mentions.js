export function parseMentionedUsernames(cooked) {
  const html = new DOMParser().parseFromString(cooked, "text/html");
  const mentions = html.querySelectorAll("a.mention[href^='/u/']");
  return Array.from(mentions, extractUsername);
}

function extractUsername(mentionNode) {
  return mentionNode.innerText.substring(1);
}
