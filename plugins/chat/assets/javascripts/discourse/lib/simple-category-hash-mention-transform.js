import getURL from "discourse-common/lib/get-url";

const domParser = new DOMParser();

export default function transform(cooked, categories) {
  const html = domParser.parseFromString(cooked, "text/html");
  transformMentions(html);
  return html.body.innerHTML;
}

function transformMentions(html) {
  (html.querySelectorAll("span.mention") || []).forEach((mentionSpan) => {
    let mentionLink = document.createElement("a");
    let mentionText = document.createTextNode(mentionSpan.innerText);
    mentionLink.classList.add("mention");
    mentionLink.appendChild(mentionText);
    mentionLink.href = getURL(`/u/${mentionSpan.innerText.substring(1)}`);
    mentionSpan.parentNode.replaceChild(mentionLink, mentionSpan);
  });
}
