import getURL from "discourse/lib/get-url";

export default function nestedPostUrl(topic, postNumber) {
  return getURL(`/t/${topic.slug}/${topic.id}/${postNumber}`);
}
