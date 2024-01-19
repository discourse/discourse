import { tracked } from "@glimmer/tracking";

export default class ListNode {
  @tracked value;
  @tracked child;
  @tracked parent;

  constructor(value, parent = null) {
    this.value = value;
    this.child = null;
    this.parent = parent;
  }
}
