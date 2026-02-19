import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { compare } from "@ember/utils";
import { Promise } from "rsvp";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class PluginsExplorerController extends Controller {
  @service dialog;
  @service appEvents;
  @service router;

  @tracked sortByProperty = "last_run_at";
  @tracked sortDescending = true;
  @tracked params;
  @tracked search;
  @tracked newQueryName;
  @tracked showCreate;
  @tracked loading = false;

  queryParams = ["id"];
  explain = false;
  acceptedImportFileTypes = ["application/json"];
  order = null;
  form = null;

  get sortedQueries() {
    const sortedQueries = this.model.content.toSorted((a, b) =>
      compare(a?.[this.sortByProperty], b?.[this.sortByProperty])
    );
    return this.sortDescending ? sortedQueries.reverse() : sortedQueries;
  }

  get parsedParams() {
    return this.params ? JSON.parse(this.params) : null;
  }

  get filteredContent() {
    const regexp = new RegExp(this.search, "i");
    return this.sortedQueries.filter(
      (result) => regexp.test(result.name) || regexp.test(result.description)
    );
  }

  get createDisabled() {
    return (this.newQueryName || "").trim().length === 0;
  }

  addCreatedRecord(record) {
    this.model.content.push(record);
    this.router.transitionTo(
      "adminPlugins.show.explorer.queries.details",
      record.id
    );
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

  @bind
  dragMove(e) {
    if (!e.movementY && !e.movementX) {
      return;
    }

    const editPane = document.querySelector(".query-editor");
    const target = editPane.querySelector(".panels-flex");
    const grippie = editPane.querySelector(".grippie");

    // we need to get the initial height / width of edit pane
    // before we manipulate the size
    if (!this.initialPaneWidth && !this.originalPaneHeight) {
      this.originalPaneWidth = target.clientWidth;
      this.originalPaneHeight = target.clientHeight;
    }

    const newHeight = Math.max(
      this.originalPaneHeight,
      target.clientHeight + e.movementY
    );
    const newWidth = Math.max(
      this.originalPaneWidth,
      target.clientWidth + e.movementX
    );

    target.style.height = newHeight + "px";
    target.style.width = newWidth + "px";
    grippie.style.width = newWidth + "px";
    this.appEvents.trigger("ace:resize");
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
      this.addCreatedRecord(record);
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
  displayCreate() {
    this.showCreate = true;
  }

  @action
  updateSortProperty(property) {
    if (this.sortByProperty === property) {
      this.sortDescending = !this.sortDescending;
    } else {
      this.sortByProperty = property;
      this.sortDescending = true;
    }
  }

  @action
  async create() {
    try {
      const name = this.newQueryName.trim();
      this.loading = true;
      this.showCreate = false;
      const result = await this.store.createRecord("query", { name }).save();
      this.addCreatedRecord(result.target);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  updateSearch(value) {
    this.search = value;
  }

  @action
  updateNewQueryName(value) {
    this.newQueryName = value;
  }
}
