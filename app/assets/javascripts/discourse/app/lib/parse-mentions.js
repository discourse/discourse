export function parseMentionedUsernames(cooked) {
  const html = new DOMParser().parseFromString(cooked, "text/html");
  const mentions = html.querySelectorAll("a.mention[href^='/u/']");
  const usernames = Array.from(mentions, extractUsername);
  return [...new Set(usernames)];
}

function extractUsername(mentionNode) {
  return mentionNode.innerText.substring(1);
}
