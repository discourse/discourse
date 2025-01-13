import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import EmptyState from "./empty-state";
import Item from "./item";

export default class List extends Component {
  loadMore = modifier((element) => {
    this.intersectionObserver = new IntersectionObserver(this.loadCollection);
    this.intersectionObserver.observe(element);

    return () => {
      this.intersectionObserver.disconnect();
    };
  });

  fill = modifier((element) => {
    this.resizeObserver = new ResizeObserver(() => {
      if (isElementInViewport(element)) {
        this.loadCollection();
      }
    });

    this.resizeObserver.observe(element);

    return () => {
      this.resizeObserver.disconnect();
    };
  });

  get itemComponent() {
    return this.args.itemComponent ?? Item;
  }

  @action
  loadCollection() {
    discourseDebounce(this, this.debouncedLoadCollection, INPUT_DELAY);
  }

  async debouncedLoadCollection() {
    await this.args.collection.load({ limit: 10 });
  }

  <template>
    <div class="c-list">
      <div {{this.fill}} ...attributes>
        {{#each @collection.items as |item|}}
          {{yield (hash Item=(component this.itemComponent item=item))}}
        {{else}}
          {{#if @collection.fetchedOnce}}
            {{yield (hash EmptyState=EmptyState)}}
          {{/if}}
        {{/each}}
      </div>

      <div {{this.loadMore}}>
        <br />
      </div>

      <ConditionalLoadingSpinner @condition={{@collection.loading}} />
    </div>
  </template>
}
