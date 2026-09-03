import { tracked } from "@glimmer/tracking";

export default class Card {
  static create(args = {}) {
    if (args instanceof Card) {
      return args;
    }
    return new Card(args);
  }

  @tracked assigned_to;
  @tracked board_id;
  @tracked card_type;
  @tracked column_id;
  @tracked created_at;
  @tracked column_changed_at;
  @tracked created_by;
  @tracked id;
  @tracked inline_onebox_data;
  @tracked notes;
  @tracked position;
  @tracked recency_at;
  @tracked tag_ids;
  @tracked tags;
  @tracked title;
  @tracked topic;
  @tracked topic_id;
  @tracked unicode_title;
  @tracked updated_at;

  constructor(args = {}) {
    Object.assign(this, args);
  }

  copy(overrides = {}) {
    return new Card({
      assigned_to: this.assigned_to,
      board_id: this.board_id,
      card_type: this.card_type,
      column_changed_at: this.column_changed_at,
      column_id: this.column_id,
      created_at: this.created_at,
      created_by: this.created_by,
      id: this.id,
      inline_onebox_data: this.inline_onebox_data,
      notes: this.notes,
      position: this.position,
      recency_at: this.recency_at,
      tag_ids: this.tag_ids,
      tags: this.tags,
      title: this.title,
      topic: this.topic,
      topic_id: this.topic_id,
      unicode_title: this.unicode_title,
      updated_at: this.updated_at,
      ...overrides,
    });
  }

  get fancyTitle() {
    const titleSource =
      this.card_type === "topic" && this.topic ? this.topic : this;
    return titleSource.unicode_title || titleSource.title;
  }
}
