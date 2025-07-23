import { ajax } from "discourse/lib/ajax";
import { clipboardCopyAsync } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default async function (topic, fromPostNumber, toPostNumber) {
  await clipboardCopyAsync(async () => {
    const text = await generateClipboard(topic, fromPostNumber, toPostNumber);
    return new Blob([text], {
      type: "text/plain",
    });
  });
}

async function generateClipboard(topic, fromPostNumber, toPostNumber) {
  const stream = topic.get("postStream");

  let postNumbers = [];
  // simpler to understand than Array.from
  for (let i = fromPostNumber; i <= toPostNumber; i++) {
    postNumbers.push(i);
  }

  const postIds = postNumbers.map((postNumber) => {
    return stream.findPostIdForPostNumber(postNumber);
  });

  // we need raw to construct so post stream will not help

  const url = `/t/${topic.id}/posts.json`;
  const data = {
    post_ids: postIds,
    include_raw: true,
  };

  const response = await ajax(url, { data });

  let buffer = [];
  buffer.push("<details class='ai-quote'>");
  buffer.push("<summary>");
  buffer.push(`<span>${topic.title}</span>`);
  buffer.push(
    `<span title='${i18n("discourse_ai.ai_bot.ai_title")}'>${i18n(
      "discourse_ai.ai_bot.ai_label"
    )}</span>`
  );
  buffer.push("</summary>");

  response.post_stream.posts.forEach((post) => {
    buffer.push("");
    buffer.push(`**${post.username}:**`);
    buffer.push("");
    buffer.push(post.raw);
  });

  buffer.push("</details>");

  const text = buffer.join("\n");

  return text;
}
