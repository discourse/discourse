import getURL from "discourse/lib/get-url";
import { generatePlaceholderHashtagHTML } from "discourse/lib/hashtag-decorator";

const domParser = new DOMParser();

export default function transformAutolinks(cooked) {
  const html = domParser.parseFromString(cooked, "text/html");
  transformMentions(html);
  transformHashtags(html);
  return html.body.innerHTML;
}

function transformMentions(html) {
  (html.querySelectorAll("span.mention") || []).forEach((mentionSpan) => {
    let mentionLink = document.createElement("a");
    let mentionText = document.createTextNode(mentionSpan.innerText);
    mentionLink.classList.add("mention");
    mentionLink.appendChild(mentionText);
    mentionLink.href = getURL(`/u/${mentionSpan.innerText.substring(1)}`);
    mentionSpan.replaceWith(mentionLink);
  });
}

function transformHashtags(html) {
  (html.querySelectorAll("span.hashtag-raw") || []).forEach((hashtagSpan) => {
    // Doesn't matter what "type" of hashtag we use here, it will get replaced anyway,
    // this is just for the placeholder HTML.
    generatePlaceholderHashtagHTML("category", hashtagSpan, {
      id: -1,
      text: "...",
      relative_url: "/",
      slug: "",
      icon: "square-full",
    });
  });
}
