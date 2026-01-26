export default function getTagName(tag) {
  // TODO(https://github.com/discourse/discourse/pull/36678): The string check can be
  // removed using .discourse-compatibility once the PR is merged.
  return typeof tag === "string" ? tag : tag.name;
}
