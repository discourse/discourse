import getURL from "discourse-common/lib/get-url";

const domParser = new DOMParser();

export default function transform(cooked, categories) {
  let html = domParser.parseFromString(cooked, "text/html");
  transformMentions(html);
  transformCategoryTagHashes(html, categories);
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

function transformCategoryTagHashes(html, categories) {
  (html.querySelectorAll("span.hashtag") || []).forEach((hashSpan) => {
    const categoryTagName = hashSpan.innerText.substring(1);
    const matchingCategory = categories.find(
      (category) =>
        category.name.toLowerCase() === categoryTagName.toLowerCase()
    );
    const href = getURL(
      matchingCategory
        ? `/c/${matchingCategory.name}/${matchingCategory.id}`
        : `/tag/${categoryTagName}`
    );

    let hashLink = document.createElement("a");
    let hashText = document.createTextNode(hashSpan.innerText);
    hashLink.classList.add("hashtag");
    hashLink.appendChild(hashText);
    hashLink.href = href;
    hashSpan.parentNode.replaceChild(hashLink, hashSpan);
  });
}
