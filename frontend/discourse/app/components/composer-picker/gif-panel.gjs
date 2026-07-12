import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import GifsResultList from "discourse/components/gifs/result-list";
import withEventValue from "discourse/helpers/with-event-value";
import getURL from "discourse/lib/get-url";
import GifSearch from "discourse/lib/gif-search";
import preventScrollOnFocus from "discourse/modifiers/prevent-scroll-on-focus";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

export default class GifPanel extends Component {
  @service dialog;
  @service siteSettings;

  search = new GifSearch({
    siteSettings: this.siteSettings,
    dialog: this.dialog,
  });

  constructor() {
    super(...arguments);
    this.search.fetchCategories();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.search.destroy();
  }

  get gifBaseWidth() {
    return 150;
  }

  @action
  pick(content) {
    const markup = `\n![${content.title}|${content.width}x${content.height}](${content.original})\n`;
    this.args.onSelect?.(markup);
    this.args.close?.();
  }

  <template>
    <div class="gif-panel">
      <div class="gif-panel__input">
        <DFilterInput
          {{preventScrollOnFocus}}
          {{dAutoFocus}}
          @value={{this.search.query}}
          @filterAction={{withEventValue this.search.refresh}}
          @onClearInput={{this.search.clearQuery}}
          @icons={{hash left="magnifying-glass"}}
          @containerClass="gif-panel__filter"
          placeholder={{i18n "gifs.search_placeholder"}}
        >
          {{#if this.search.loading}}
            {{dLoadingSpinner size="small"}}
          {{/if}}
        </DFilterInput>
      </div>

      {{#if this.search.currentGifs.length}}
        <div class="gif-panel__content">
          <div class="gif-panel__box">
            <GifsResultList
              @content={{this.search.currentGifs}}
              @pick={{this.pick}}
              @loading={{this.search.loading}}
              @loadMore={{this.search.loadMore}}
              @canLoadMore={{this.search.hasMore}}
              @baseWidth={{this.gifBaseWidth}}
              @root=".gif-panel__content"
            />
          </div>
        </div>
      {{else if this.search.showingCategories}}
        <div class="gif-panel__content">
          <h3 class="gif-panel__categories-header">{{i18n
              "gifs.browse_categories"
            }}</h3>
          <div class="gif-panel__box">
            <GifsResultList
              @content={{this.search.categories}}
              @pick={{this.search.selectCategory}}
              @loading={{false}}
              @baseWidth={{this.gifBaseWidth}}
            />
          </div>
        </div>
      {{else if this.search.loadingCategories}}
        <div class="gif-panel__loading-categories">
          {{dLoadingSpinner size="medium"}}
        </div>
      {{else}}
        <div class="gif-panel__no-results">{{i18n "gifs.no_results"}}</div>
      {{/if}}

      <div class="gif-panel__branding">
        <img
          class="gif-panel__branding-logo"
          src={{getURL "/images/klipy-logo.png"}}
          alt={{i18n "gifs.powered_by"}}
        />
      </div>
    </div>
  </template>
}
