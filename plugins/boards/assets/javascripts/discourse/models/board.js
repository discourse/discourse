import { tracked } from "@glimmer/tracking";
import Column from "./column";

export default class Board {
  static createPayload(data) {
    return {
      ...data,
      board: Board.create(data.board),
      columns: (data.columns || []).map((column) => Column.create(column)),
    };
  }

  static create(args = {}) {
    if (args instanceof Board) {
      return args;
    }
    return new Board(args);
  }

  @tracked anonymous_can_read;
  @tracked can_manage;
  @tracked can_write;
  @tracked card_style;
  @tracked category_ids;
  @tracked columns;
  @tracked id;
  @tracked name;
  @tracked require_confirmation;
  @tracked show_tags;
  @tracked show_topic_thumbnail;
  @tracked slug;
  @tracked tag_ids;
  @tracked tag_names;
  @tracked unicode_name;

  constructor(args = {}) {
    Object.assign(this, args);
    this.columns = (args.columns || []).map((column) => Column.create(column));
  }

  get fancyTitle() {
    return this.unicode_name || this.name;
  }
}
