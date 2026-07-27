import { i18n } from "discourse-i18n";

export default function sectionTitle(id) {
  return i18n(`styleguide.sections.${id.replaceAll("-", "_")}.title`);
}
