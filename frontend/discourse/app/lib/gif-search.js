import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { addUniqueValuesToArray } from "discourse/lib/array-tools";
import discourseDebounce from "discourse/lib/debounce";
import getURL from "discourse/lib/get-url";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";

const GIFS_SEARCH_URL = "/gifs/search.json";
const GIFS_CATEGORIES_URL = "/gifs/categories.json";
const SEARCH_DEBOUNCE = 700;

const MIN_QUERY_LENGTH = 3;

export default class GifSearch {
  @tracked categories = [];
  @tracked loading = false;
  @tracked loadingCategories = false;
  @tracked offset = 0;
  @tracked query = "";
  @tracked hasMore = true;
  @autoTrackedArray currentGifs = [];

  isDestroyed = false;

  constructor({ siteSettings, dialog }) {
    this.siteSettings = siteSettings;
    this.dialog = dialog;
  }

  destroy() {
    this.isDestroyed = true;
    cancel(this.debouncedSearch);
  }

  get showingCategories() {
    return this.query.length < MIN_QUERY_LENGTH && this.categories.length > 0;
  }

  @action
  refresh(value) {
    this.query = value;
    this.debouncedSearch = discourseDebounce(
      this,
      this.search,
      SEARCH_DEBOUNCE
    );
  }

  @action
  clearQuery() {
    this.query = "";
    this.search();
  }

  @action
  selectCategory(category) {
    this.query = category.searchterm;
    this.search(true, true);
  }

  @action
  async loadMore() {
    if (this.loading || !this.hasMore) {
      return;
    }
    await this.search(false);
  }

  async fetchCategories() {
    this.loadingCategories = true;

    try {
      const response = await fetch(getURL(GIFS_CATEGORIES_URL));

      if (this.isDestroyed || !response.ok) {
        return;
      }

      const data = await response.json();

      if (this.isDestroyed) {
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

      if (this.isDestroyed) {
        return;
      }

      if (!response.ok) {
        throw new Error(await this.errorFromResponse(response));
      }

      const data = await response.json();
      if (this.isDestroyed) {
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
      if (this.isDestroyed) {
        return;
      }
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
}
