import { tracked } from "@glimmer/tracking";

// A row's open state: the default it is given, until a click overrides it. The
// click is remembered against the filter it was made under, so a new search
// starts from its own default.
export default class Expansion {
  @tracked choice = null;
  @tracked choiceFilter = "";

  toggle = () => {
    this.choice = !this.expanded;
    this.choiceFilter = this.#filter();
  };
  #defaultTo;

  #filter;

  constructor({ defaultTo, filter }) {
    this.#defaultTo = defaultTo;
    this.#filter = filter;
  }

  get expanded() {
    if (this.choice !== null && this.choiceFilter === this.#filter()) {
      return this.choice;
    }
    return this.#defaultTo();
  }
}
