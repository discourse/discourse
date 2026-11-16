import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { Promise } from "rsvp";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import { applyQueryParams } from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import { findQueries } from "discourse/plugins/discourse-data-explorer/discourse/data/builders/queries";

export default class PluginsExplorerController extends Controller {
  @service dialog;
  @service router;
  @service store;
  @service warpStore;

  @tracked sortByProperty = "last_run_at";
  @tracked sortDescending = true;
  @tracked loading = false;
  @tracked searchLoading = false;
  @tracked queryTags = [];
  @tracked tags = "";
  @tracked pages = [];
  @tracked loadingMore = false;

  queryParams = ["id", "tags"];
  acceptedImportFileTypes = ["application/json"];
  #latestQueryRequest;
  _currentFilter = "";

  get fetchParams() {
    return {
      search: this._currentFilter,
      tags: this.currentTags,
      sort: this.sortByProperty,
      descending: this.sortDescending,
    };
  }

  get queries() {
    return this.pages.flatMap((page) => page.data);
  }

  get canLoadMore() {
    return !!this.pages.at(-1)?.links?.next;
  }

  get hasTagFilter() {
    return this.currentTags.length > 0;
  }

  get currentTags() {
    return this.tags ? this.tags.split(",") : [];
  }

  get textFilter() {
    return this._currentFilter;
  }

  get tagSelection() {
    return this.currentTags.map((tag) => ({ id: tag, name: tag }));
  }

  reset(document, queryTags) {
    this.#latestQueryRequest = null;
    this.searchLoading = false;
    this.pages = [document];
    this.queryTags = queryTags;
  }

  @bind
  scrollTop() {
    window.scrollTo(0, 0);
  }

  @action
  async import(files) {
    try {
      this.loading = true;
      const file = files[0];
      const record = await this._importQuery(file);
      this.router.transitionTo("adminPlugins.show.explorer.edit", record.id);
    } catch (e) {
      if (e.jqXHR) {
        popupAjaxError(e);
      } else if (e instanceof SyntaxError) {
        this.dialog.alert(i18n("explorer.import.unparseable_json"));
      } else if (e instanceof TypeError) {
        this.dialog.alert(i18n("explorer.import.wrong_json"));
      } else {
        this.dialog.alert(i18n("errors.desc.unknown"));
        // eslint-disable-next-line no-console
        console.error(e);
      }
    } finally {
      this.loading = false;
    }
  }

  @action
  onTextFilterChange(event) {
    this._currentFilter = event.target?.value || "";
    this.#latestQueryRequest = null;
    this.searchLoading = true;
    discourseDebounce(this, this._fetchQueries, INPUT_DELAY);
  }

  @action
  async loadTags(searchTerm) {
    const term = (searchTerm || "").toLowerCase();
    return this.queryTags
      .filter((tag) => tag.toLowerCase().includes(term))
      .map((tag) => ({ id: tag, name: tag }));
  }

  @action
  onTagFilterChange(selection) {
    this.tags = selection.map((tag) => tag.name).join(",");
    this.searchLoading = true;
    this._fetchQueries();
  }

  @action
  addTagFilter(tagName, event) {
    event?.preventDefault();

    if (this.currentTags.includes(tagName)) {
      return;
    }

    this.tags = [...this.currentTags, tagName].join(",");
    this.searchLoading = true;
    this._fetchQueries();
  }

  @action
  tagFilterHref(tagName) {
    return getURL(
      applyQueryParams(this.router.urlFor("adminPlugins.show.explorer.index"), {
        tags: tagName,
      })
    );
  }

  @action
  onResetFilters() {
    this._currentFilter = "";
    this.tags = "";
    this.searchLoading = true;
    this._fetchQueries();
  }

  @action
  updateSortProperty(property) {
    if (this.sortByProperty === property) {
      this.sortDescending = !this.sortDescending;
    } else {
      this.sortByProperty = property;
      this.sortDescending = true;
    }
    this.searchLoading = true;
    this._fetchQueries();
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.canLoadMore) {
      return;
    }

    const last = this.pages.at(-1);
    this.loadingMore = true;
    try {
      const page = await last.next();
      // Drop the page if the list was replaced meanwhile.
      if (this.pages.at(-1) === last) {
        this.pages = [...this.pages, page];
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }

  async _importQuery(file) {
    const json = await this._readFileAsTextAsync(file);
    const query = this._parseQuery(json);
    const record = this.store.createRecord("query", query);
    const response = await record.save();
    return response.target;
  }

  _parseQuery(json) {
    const parsed = JSON.parse(json);
    const query = parsed.query;
    if (!query || !query.sql) {
      throw new TypeError();
    }
    query.id = 0; // 0 means no Id yet
    return query;
  }

  _readFileAsTextAsync(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        resolve(reader.result);
      };
      reader.onerror = reject;

      reader.readAsText(file);
    });
  }

  async _fetchQueries() {
    const request = (this.#latestQueryRequest = {});

    try {
      const { content } = await this.warpStore.request(
        findQueries(this.fetchParams)
      );

      if (request === this.#latestQueryRequest) {
        this.pages = [content];
      }
    } catch (e) {
      if (request === this.#latestQueryRequest) {
        popupAjaxError(e);
      }
    } finally {
      if (request === this.#latestQueryRequest) {
        this.searchLoading = false;
      }
    }
  }
}
