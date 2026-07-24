import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import GifsResultList from "discourse/components/gifs/result-list";
import { addUniqueValuesToArray } from "discourse/lib/array-tools";
import discourseDebounce from "discourse/lib/debounce";
import getURL from "discourse/lib/get-url";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { or } from "discourse/truth-helpers";
import DModal from "discourse/ui-kit/d-modal";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";

const GIFS_SEARCH_URL = "/gifs/search.json";
const GIFS_CATEGORIES_URL = "/gifs/categories.json";
const MIN_QUERY_LENGTH = 3;

export default class GifsModal extends Component {
  @service appEvents;
  @service dialog;
  @service interfaceColor;
  @service siteSettings;

  @tracked categories = [];
  @tracked loading = false;
  @tracked loadingCategories = false;
  @tracked searchPending = false;
  @tracked offset = 0;
  @tracked query = "";
  @tracked hasMore = true;
  @autoTrackedArray currentGifs = [];

  constructor() {
    super(...arguments);
    this.fetchCategories();
  }

  get showingCategories() {
    return this.query.length < MIN_QUERY_LENGTH && this.categories.length > 0;
  }

  get darkMediaQuery() {
    if (this.interfaceColor.darkModeForced) {
      return "all";
    } else if (this.interfaceColor.lightModeForced) {
      return "none";
    } else {
      return "(prefers-color-scheme: dark)";
    }
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

  @action
  async loadMore() {
    if (this.loading || !this.hasMore) {
      return;
    }
    await this.search(false);
  }

  @action
  refresh(event) {
    this.query = event.target.value;
    this.searchPending = this.query.length >= MIN_QUERY_LENGTH;
    discourseDebounce(this, this.search, 700);
  }

  @action
  selectCategory(category) {
    this.query = category.searchterm;
    this.search(true, true);
  }

  async fetchCategories() {
    this.loadingCategories = true;

    try {
      const response = await fetch(getURL(GIFS_CATEGORIES_URL));

      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      if (!response.ok) {
        return;
      }

      const data = await response.json();

      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.categories = await this.loadCategoryDimensions(data.tags || []);
    } catch {
      // Silently fail - user can still search manually
    } finally {
      this.loadingCategories = false;
    }
  }

  async loadCategoryDimensions(tags) {
    return Promise.all(
      tags.map(
        (tag) =>
          new Promise((resolve) => {
            const img = new Image();
            const finish = (width, height) => {
              resolve({
                title: tag.name,
                preview: tag.image,
                original: tag.image,
                width,
                height,
                isCategory: true,
                searchterm: tag.searchterm,
              });
            };
            img.onload = () => finish(img.naturalWidth, img.naturalHeight);
            img.onerror = () => finish(200, 150);
            img.src = tag.image;
          })
      )
    );
  }

  async search(clearResults = true, skipLengthCheck = false) {
    this.searchPending = false;

    if (clearResults) {
      this.currentGifs = [];
      this.offset = 0;
      this.hasMore = true;
    }

    const meetsLengthRequirement =
      skipLengthCheck || this.query.length >= MIN_QUERY_LENGTH;

    if (!meetsLengthRequirement) {
      return;
    }

    const limitReached =
      this.siteSettings.klipy_limit_infinite_search_results &&
      this.currentGifs.length >= this.siteSettings.klipy_max_results_limit;

    if (limitReached) {
      this.hasMore = false;
      return;
    }

    this.loading = true;

    try {
      const response = await fetch(this.getEndpoint(this.query, this.offset));

      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      if (!response.ok) {
        throw new Error(await this.errorFromResponse(response));
      }

      const data = await response.json();
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      const fileDetail = this.siteSettings.klipy_file_detail;
      const images = data.results.map((gif) => {
        const mediaFormat = gif.media_formats[fileDetail];
        return {
          title: gif.title,
          preview: mediaFormat.url,
          original: mediaFormat.url,
          width: mediaFormat.dims[0],
          height: mediaFormat.dims[1],
        };
      });

      if (data.next === "" || data.next == null) {
        this.hasMore = false;
      } else {
        this.offset = data.next;
      }
      addUniqueValuesToArray(this.currentGifs, images);
    } catch (error) {
      this.dialog.alert({ message: error.message ?? error });
    } finally {
      this.loading = false;
    }
  }

  async errorFromResponse(response) {
    if (response.status === 429) {
      return i18n("gifs.error_rate_limit");
    }
    if (response.status === 414) {
      return i18n("gifs.error_search_too_long");
    }
    if (response.status === 403 || response.status === 401) {
      return i18n("gifs.bad_api_key");
    }

    const body = await response.text().catch(() => "");

    let parsed;
    try {
      parsed = body && JSON.parse(body);
    } catch {
      parsed = null;
    }

    const message = this.extractErrorMessage(parsed) ?? body ?? "unknown error";

    if (/api key is invalid|API_KEY_INVALID/i.test(message)) {
      return i18n("gifs.bad_api_key");
    }

    return `Klipy status ${response.status}: ${message}`;
  }

  extractErrorMessage(parsed) {
    if (!parsed) {
      return null;
    }
    // Klipy: { result: false, errors: { message: ["..."] } }
    const klipyMessages = parsed.errors?.message;
    if (Array.isArray(klipyMessages) && klipyMessages.length) {
      return klipyMessages[0];
    }
    // Google-style: { error: { message, details: [{ reason }] } }
    return (
      parsed.error?.message ??
      (typeof parsed.error === "string" ? parsed.error : null) ??
      parsed.message ??
      null
    );
  }

  getEndpoint(query, offset) {
    const params = {
      q: query,
      pos: offset,
    };
    return getURL(`${GIFS_SEARCH_URL}?${new URLSearchParams(params)}`);
  }

  <template>
    <DModal
      @title={{i18n "gifs.modal_title"}}
      @closeModal={{@closeModal}}
      id="gifs-modal"
      class="gifs-modal"
    >
      <:body>
        <div class="gifs-modal__input">
          <Input
            {{on "input" this.refresh}}
            @type="text"
            @value={{this.query}}
            name="query"
            placeholder={{i18n "gifs.placeholder"}}
            autofocus
          />

          {{#if this.loading}}
            <div class="gifs-modal__input-spinner">
              {{dLoadingSpinner size="small"}}
            </div>
          {{/if}}
        </div>

        {{#if this.currentGifs.length}}
          <div class="gifs-modal__content">
            <div class="gifs-modal__box">
              <GifsResultList
                @content={{this.currentGifs}}
                @pick={{this.pick}}
                @loading={{this.loading}}
                @loadMore={{this.loadMore}}
                @canLoadMore={{this.hasMore}}
              />
            </div>
          </div>
        {{else if this.showingCategories}}
          <div class="gifs-modal__content">
            <h3 class="gifs-modal__categories-header">{{i18n
                "gifs.browse_categories"
              }}</h3>
            <div class="gifs-modal__box">
              <GifsResultList
                @content={{this.categories}}
                @pick={{this.selectCategory}}
                @loading={{false}}
              />
            </div>
          </div>
        {{else if (or this.loading this.searchPending this.loadingCategories)}}
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
            srcset={{getURL "/images/klipy-logo-dark.png"}}
            media={{this.darkMediaQuery}}
          />
          <img
            class="gifs-modal__branding"
            src={{getURL "/images/klipy-logo.png"}}
            alt={{i18n "gifs.powered_by"}}
          />
        </picture>
      </:footer>
    </DModal>
  </template>
}
