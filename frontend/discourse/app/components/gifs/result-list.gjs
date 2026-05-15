import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import GifsResult from "discourse/components/gifs/result";
import MiniMasonry from "discourse/lib/mini-masonry";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";

export default class GifsResultList extends Component {
  @service site;

  observer;
  masonry;

  willDestroy() {
    super.willDestroy(...arguments);
    this.observer?.disconnect();
  }

  @action
  setup() {
    this.observer = new IntersectionObserver(() => {
      const scroller = document.querySelector(".gifs-modal__content");
      if (scroller?.scrollTop > 0 && this.args.content?.length > 0) {
        this.args.loadMore?.();
      }
    });

    const target = document.querySelector(
      ".gifs-modal__box .loading-container"
    );
    if (target) {
      this.observer.observe(target);
    }

    this.masonry = new MiniMasonry({
      container: ".gifs-result-list",
      baseWidth: this.site.mobileView ? 145 : 200,
      surroundingGutter: false,
    });

    schedule("afterRender", () => this.masonry.layout());
  }

  @action
  update() {
    schedule("afterRender", () => this.masonry.layout());
  }

  <template>
    <div
      {{didInsert this.setup}}
      {{didUpdate this.update @content.length}}
      class="gifs-result-list"
    >
      {{#each @content key="preview" as |result|}}
        <GifsResult @gif={{result}} @pick={{@pick}} />
      {{/each}}

      <DConditionalLoadingSpinner @condition={{@loading}} />
    </div>
  </template>
}
