import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import GifsResult from "discourse/components/gifs/result";
import loadMiniMasonry from "discourse/lib/load-minimasonry";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";

export default class GifsResultList extends Component {
  @service site;

  masonry;

  willDestroy() {
    super.willDestroy(...arguments);
    this.masonry?.destroy();
  }

  get loadMoreEnabled() {
    return this.args.content?.length > 0 && (this.args.canLoadMore ?? true);
  }

  @action
  async setup() {
    const MiniMasonry = await loadMiniMasonry();

    this.masonry = new MiniMasonry({
      container: ".gifs-result-list",
      baseWidth: this.site.mobileView ? 145 : 200,
      surroundingGutter: false,
    });

    schedule("afterRender", () => this.masonry.layout());
  }

  @action
  update() {
    schedule("afterRender", () => this.masonry?.layout());
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
    </div>

    {{#if @loadMore}}
      <DLoadMore
        @action={{@loadMore}}
        @root=".gifs-modal__content"
        @isLoading={{@loading}}
        @enabled={{this.loadMoreEnabled}}
      />
    {{/if}}

    <DConditionalLoadingSpinner @condition={{@loading}} />
  </template>
}
