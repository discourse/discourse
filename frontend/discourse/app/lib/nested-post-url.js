import getURL from "discourse/lib/get-url";

export default function nestedPostUrl(topic, postNumber) {
  return getURL(`/n/${topic.slug}/${topic.id}/${postNumber}`);
}
