import { tracked } from "@glimmer/tracking";
import Card from "./card";

export default class Column {
  static create(args = {}) {
    if (args instanceof Column) {
      return args;
    }
    return new Column(args);
  }

  @tracked cards;
  @tracked color;
  @tracked default_sort;
  @tracked icon;
  @tracked id;
  @tracked move_to_assigned;
  @tracked move_to_category_id;
  @tracked move_to_status;
  @tracked position;
  @tracked tag_id;
  @tracked tag_name;
  @tracked title;
  @tracked unicode_title;

  constructor(args = {}) {
    Object.assign(this, args);
    this.cards = (args.cards || []).map((card) => Card.create(card));
  }

  copy(overrides = {}) {
    return new Column({
      cards: this.cards,
      color: this.color,
      default_sort: this.default_sort,
      icon: this.icon,
      id: this.id,
      move_to_assigned: this.move_to_assigned,
      move_to_category_id: this.move_to_category_id,
      move_to_status: this.move_to_status,
      position: this.position,
      tag_id: this.tag_id,
      tag_name: this.tag_name,
      title: this.title,
      unicode_title: this.unicode_title,
      ...overrides,
    });
  }

  get fancyTitle() {
    return this.unicode_title || this.title;
  }
}
