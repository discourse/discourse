import func from "@embroider/template-tag-codemod/default-renaming";

export default function renaming(name /*, kind */) {
  if (name === "d-icon") {
    return "icon";
  }

  return func(...arguments);
}
