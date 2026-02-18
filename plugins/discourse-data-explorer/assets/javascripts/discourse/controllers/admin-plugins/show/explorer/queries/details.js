import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { bind } from "discourse/lib/decorators";
import QueryHelp from "discourse/plugins/discourse-data-explorer/discourse/components/modal/query-help";
import { ParamValidationError } from "discourse/plugins/discourse-data-explorer/discourse/components/param-input-form";
import Query from "discourse/plugins/discourse-data-explorer/discourse/models/query";

export default class PluginsExplorerController extends Controller {
  @service modal;
  @service appEvents;
  @service router;

  @tracked params;
  @tracked editingName = false;
  @tracked editingQuery = false;
  @tracked loading = false;
  @tracked showResults = false;
  @tracked hideSchema = false;
  @tracked results = this.model.results;
  @tracked dirty = false;

  queryParams = ["params"];
  explain = false;
  order = null;
  form = null;
  shouldAutoRun = false;

  get saveDisabled() {
    return !this.dirty;
  }

  get runDisabled() {
    return this.dirty;
  }

  get parsedParams() {
    return this.params ? JSON.parse(this.params) : null;
  }

  get editDisabled() {
    return parseInt(this.model.id, 10) < 0 ? true : false;
  }

  get groupOptions() {
    return this.groups
      .filter((g) => g.id !== AUTO_GROUPS.everyone.id)
      .map((g) => {
        return { id: g.id, name: g.name };
      });
  }

  @action
  async save() {
    try {
      this.loading = true;
      await this.model.save();

      this.dirty = false;
      this.editingName = false;
    } catch (error) {
      popupAjaxError(error);
      throw error;
    } finally {
      this.loading = false;
    }
  }

  @action
  saveAndRun() {
    this.save().then(() => this.run());
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
  didStartDrag() {}

  @bind
  didEndDrag() {}

  @action
  updateGroupIds(value) {
    this.dirty = true;
    this.model.set("group_ids", value);
  }

  @action
  updateHideSchema(value) {
    this.hideSchema = value;
  }

  @action
  editName() {
    this.editingName = true;
  }

  @action
  editQuery() {
    this.editingQuery = true;
  }

  @action
  download() {
    window.open(this.model.downloadUrl, "_blank");
  }

  @action
  goHome() {
    this.router.transitionTo("adminPlugins.show.explorer");
  }

  @action
  showHelpModal() {
    this.modal.show(QueryHelp);
  }

  @action
  resetParams() {
    this.model.resetParams();
  }

  @action
  async discard() {
    try {
      this.loading = true;
      const result = await this.store.find("query", this.model.id);
      this.model.setProperties(result.getProperties(Query.updatePropertyNames));
      if (!this.model.group_ids || !Array.isArray(this.model.group_ids)) {
        this.model.set("group_ids", []);
      }
      this.dirty = false;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async destroyQuery() {
    try {
      this.loading = true;
      this.showResults = false;
      await this.store.destroyRecord("query", this.model);
      this.model.set("destroyed", true);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async recover() {
    try {
      this.loading = true;
      this.showResults = true;
      await this.model.save();
      this.model.set("destroyed", false);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  onRegisterApi(form) {
    this.form = form;
  }

  @action
  setDirty() {
    this.dirty = true;
  }

  @action
  exitEdit() {
    this.editingName = false;
  }

  @action
  async run() {
    let params = null;
    if (this.model.hasParams) {
      try {
        params = await this.form?.submit();
      } catch (err) {
        if (err instanceof ParamValidationError) {
          return;
        }
      }
      if (params == null) {
        return;
      }
    }
    this.setProperties({
      loading: true,
      showResults: false,
      params: JSON.stringify(params),
    });

    ajax(
      "/admin/plugins/discourse-data-explorer/queries/" +
        this.model.id +
        "/run",
      {
        type: "POST",
        data: {
          params: JSON.stringify(params),
          explain: this.explain,
        },
      }
    )
      .then((result) => {
        this.results = result;
        if (!result.success) {
          this.showResults = false;
          return;
        }
        this.showResults = true;
      })
      .catch((err) => {
        this.showResults = false;
        if (err.jqXHR && err.jqXHR.status === 422 && err.jqXHR.responseJSON) {
          this.results = err.jqXHR.responseJSON;
        } else {
          popupAjaxError(err);
        }
      })
      .finally(() => (this.loading = false));
  }

  @action
  runOnLoad() {
    if (this.shouldAutoRun) {
      this.run();
    }
  }
}
