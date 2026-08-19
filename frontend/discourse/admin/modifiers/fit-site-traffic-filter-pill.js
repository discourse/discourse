import { registerDestructor } from "@ember/destroyable";
import { schedule } from "@ember/runloop";
import Modifier from "ember-modifier";

export default class FitSiteTrafficFilterPill extends Modifier {
  #destroyed = false;
  #element;
  #filterKey;
  #filtersWidth;
  #maximumVisibleCount;
  #observer;
  #setVisibleCount;
  #signature;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, () => this.#cleanup());
  }

  modify(
    element,
    [filterKey, maximumVisibleCount, signature, setVisibleCount]
  ) {
    const contentChanged =
      signature !== this.#signature ||
      maximumVisibleCount !== this.#maximumVisibleCount;

    this.#element = element;
    this.#filterKey = filterKey;
    this.#maximumVisibleCount = maximumVisibleCount;
    this.#setVisibleCount = setVisibleCount;
    this.#signature = signature;
    this.#observeContainer();

    if (contentChanged) {
      this.#fit();
    }
  }

  #observeContainer() {
    if (this.#observer) {
      return;
    }

    const filters = this.#element.closest(".site-traffic-explorer__filters");
    this.#observer = new ResizeObserver(([entry]) => {
      const width = entry.contentRect.width;
      if (width !== this.#filtersWidth) {
        this.#filtersWidth = width;
        this.#fit();
      }
    });
    if (filters) {
      this.#observer.observe(filters);
    }
  }

  #fit(visibleCount = this.#maximumVisibleCount) {
    if (this.#destroyed) {
      return;
    }

    schedule("afterRender", () => {
      if (this.#destroyed) {
        return;
      }

      this.#setVisibleCount(this.#filterKey, visibleCount);
      schedule("afterRender", () => this.#reduceVisibleValues(visibleCount));
    });
  }

  #reduceVisibleValues(visibleCount) {
    if (this.#destroyed) {
      return;
    }

    const values = this.#element.querySelector(
      ".site-traffic-explorer__filter-pill-values"
    );
    if (
      values &&
      values.scrollWidth > values.clientWidth + 1 &&
      visibleCount > 1
    ) {
      this.#fit(visibleCount - 1);
    }
  }

  #cleanup() {
    this.#destroyed = true;
    this.#observer?.disconnect();
  }
}
