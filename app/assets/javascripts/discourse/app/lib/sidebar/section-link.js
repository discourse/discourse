import { tracked } from "@glimmer/tracking";

export default class SectionLink {
  @tracked linkDragCss;

  constructor({ external, icon, id, name, value }, section) {
    this.external = external;
    this.prefixValue = icon;
    this.id = id;
    this.name = name;
    this.text = name;
    this.value = value;
    this.section = section;
    this.withAnchor = value.match(/#\w+$/gi);
  }

  get shouldDisplay() {
    return true;
  }
}
