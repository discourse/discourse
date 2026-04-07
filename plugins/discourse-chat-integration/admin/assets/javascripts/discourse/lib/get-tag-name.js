export default function getTagName(tag) {
  return typeof tag === "string" ? tag : tag.name;
}
