import { tracked } from "@glimmer/tracking";

export default class TrackedMediaQuery {
  @tracked matches;
  #matcher;

  #handleChange = () => {
    this.matches = this.#matcher.matches;
  };

  constructor(query) {
    this.#matcher = window.matchMedia(query);
    this.#matcher.addEventListener("change", this.#handleChange);
    this.matches = this.#matcher.matches;
  }

  teardown() {
    this.#matcher.removeEventListener("change", this.#handleChange);
  }
}
