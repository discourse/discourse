import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import GifsResultList from "discourse/components/gifs/result-list";
import withEventValue from "discourse/helpers/with-event-value";
import getURL from "discourse/lib/get-url";
import GifSearch from "discourse/lib/gif-search";
import { or } from "discourse/truth-helpers";
import DModal from "discourse/ui-kit/d-modal";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";

export default class GifsModal extends Component {
  @service appEvents;
  @service dialog;
  @service interfaceColor;
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

  @action
  pick(content) {
    const markup = `\n![${content.title}|${content.width}x${content.height}](${content.original})\n`;

    if (this.args.model?.customPickHandler) {
      this.args.model.customPickHandler(markup);
    } else {
      this.appEvents.trigger("composer:insert-text", markup);
    }

    this.args.closeModal();
  }

  <template>
    <DModal
      class="gifs-modal"
      id="gifs-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "gifs.modal_title"}}
    >
      <:body>
        <div class="gifs-modal__input">
          <Input
            autofocus
            name="query"
            placeholder={{i18n "gifs.placeholder"}}
            @type="text"
            @value={{this.search.query}}
            {{on "input" (withEventValue this.search.refresh)}}
          />

          {{#if this.search.loading}}
            <div class="gifs-modal__input-spinner">
              {{dLoadingSpinner size="small"}}
            </div>
          {{/if}}
        </div>

        {{#if this.search.currentGifs.length}}
          <div class="gifs-modal__content">
            <div class="gifs-modal__box">
              <GifsResultList
                @canLoadMore={{this.search.hasMore}}
                @content={{this.search.currentGifs}}
                @loading={{this.search.loading}}
                @loadMore={{this.search.loadMore}}
                @pick={{this.pick}}
                @root=".gifs-modal__content"
              />
            </div>
          </div>
        {{else if this.search.showingCategories}}
          <div class="gifs-modal__content">
            <h3 class="gifs-modal__categories-header">{{i18n
                "gifs.browse_categories"
              }}</h3>
            <div class="gifs-modal__box">
              <GifsResultList
                @content={{this.search.categories}}
                @loading={{false}}
                @pick={{this.search.selectCategory}}
              />
            </div>
          </div>
        {{else if
          (or
            this.search.loading
            this.search.searchPending
            this.search.loadingCategories
          )
        }}
          <div class="gifs-modal__loading">
            {{dLoadingSpinner size="medium"}}
          </div>
        {{else}}
          <div class="gifs-modal__no-results">{{i18n "gifs.no_results"}}</div>
        {{/if}}
      </:body>

      <:footer>
        <picture>
          <source
            media={{this.interfaceColor.darkMediaQuery}}
            srcset={{getURL "/images/klipy-logo-dark.png"}}
          />
          <img
            alt={{i18n "gifs.powered_by"}}
            class="gifs-modal__branding"
            src={{getURL "/images/klipy-logo.png"}}
          />
        </picture>
      </:footer>
    </DModal>
  </template>
}
