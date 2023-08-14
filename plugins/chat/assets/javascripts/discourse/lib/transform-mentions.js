import getURL from "discourse-common/lib/get-url";

const domParser = new DOMParser();

export default function transformMentions(cooked) {
  const html = domParser.parseFromString(cooked, "text/html");
  transform(html);
  return html.body.innerHTML;
}

function transform(html) {
  (html.querySelectorAll("span.mention") || []).forEach((mentionSpan) => {
    let mentionLink = document.createElement("a");
    let mentionText = document.createTextNode(mentionSpan.innerText);
    mentionLink.classList.add("mention");
    mentionLink.appendChild(mentionText);
    mentionLink.href = getURL(`/u/${mentionSpan.innerText.substring(1)}`);
    mentionSpan.parentNode.replaceChild(mentionLink, mentionSpan);
  });
}
