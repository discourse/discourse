import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { bind } from "discourse/lib/decorators";
import KeyValueStore from "discourse/lib/key-value-store";
import QueryHelp from "discourse/plugins/discourse-data-explorer/discourse/components/modal/query-help";
import { ParamValidationError } from "discourse/plugins/discourse-data-explorer/discourse/components/param-input-form";
import { chartability } from "discourse/plugins/discourse-data-explorer/discourse/lib/chart-helpers";
import Query from "discourse/plugins/discourse-data-explorer/discourse/models/query";

const viewStore = new KeyValueStore("discourse_data_explorer_");

export default class PluginsExplorerController extends Controller {
  @service modal;
  @service appEvents;

  @tracked params;
  @tracked editingName = false;
  @tracked loading = false;
  @tracked showResults = false;
  @tracked results = this.model.results;
  @tracked dirty = false;
  @tracked isCachedResult = false;
  @tracked view = "table";

  queryParams = ["params"];
  order = null;
  form = null;
  shouldAutoRun = false;
  _pristine = null;

  constructor() {
    super(...arguments);
    if (this.model?.results) {
      this.initView();
    }
    if (this.model) {
      this.snapshotPristine();
    }
  }

  snapshotPristine() {
    if (!this.model) {
      return;
    }
    this._pristine = {
      name: this.model.name ?? "",
      description: this.model.description ?? "",
      sql: this.model.sql ?? "",
      group_ids: [...(this.model.group_ids ?? [])].sort().join(","),
    };
    this.dirty = false;
  }

  recomputeDirty() {
    if (!this._pristine) {
      this.dirty = true;
      return;
    }
    const current = {
      name: this.model.name ?? "",
      description: this.model.description ?? "",
      sql: this.model.sql ?? "",
      group_ids: [...(this.model.group_ids ?? [])].sort().join(","),
    };
    this.dirty =
      current.name !== this._pristine.name ||
      current.description !== this._pristine.description ||
      current.sql !== this._pristine.sql ||
      current.group_ids !== this._pristine.group_ids;
  }

  get saveDisabled() {
    return !this.dirty;
  }

  get runDisabled() {
    return this.model.destroyed;
  }

  get parsedParams() {
    return this.params ? JSON.parse(this.params) : null;
  }

  get cachedAt() {
    if (this.isCachedResult && this.results?.cached_at) {
      return this.results.cached_at;
    }
    return null;
  }

  get editDisabled() {
    return this.model.is_default;
  }

  get editingQuery() {
    return !this.editDisabled && !this.model.destroyed;
  }

  get editorDisabled() {
    return this.model.destroyed;
  }

  get groupOptions() {
    return this.groups
      .filter((g) => g.id !== AUTO_GROUPS.everyone.id)
      .map((g) => {
        return { id: g.id, name: g.name };
      });
  }

  get hasResults() {
    return !!this.results?.rows?.length;
  }

  get runButtonLabel() {
    return this.dirty ? "explorer.saverun" : "explorer.run";
  }

  get viewItems() {
    return [
      { value: "chart", icon: "signal" },
      { value: "table", icon: "table" },
    ];
  }

  initView() {
    const queryId = this.model?.id;
    const stored = queryId ? viewStore.get(`view_${queryId}`) : null;
    if (stored === "chart" || stored === "table") {
      this.view = stored;
    } else {
      this.view = chartability(this.results).chartable ? "chart" : "table";
    }
  }

  @action
  setView(value) {
    this.view = value;
    const queryId = this.model?.id;
    if (queryId) {
      viewStore.set({ key: `view_${queryId}`, value });
    }
  }

  @action
  async save() {
    try {
      this.loading = true;
      await this.model.save();

      this.snapshotPristine();
      this.editingName = false;
    } catch (error) {
      popupAjaxError(error);
      throw error;
    } finally {
      this.loading = false;
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
    this.model.set("group_ids", value);
    this.recomputeDirty();
  }

  @action
  editName() {
    this.editingName = true;
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
      this.snapshotPristine();
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
    this.recomputeDirty();
  }

  @action
  updateSql(value) {
    if (this.model.sql === value) {
      return;
    }
    this.model.set("sql", value);
    this.recomputeDirty();
  }

  @action
  exitEdit() {
    this.editingName = false;
  }

  @action
  async run(explain = false) {
    // catch any dirty state that onChange may not have flushed yet
    this.recomputeDirty();

    if (this.dirty) {
      try {
        await this.save();
      } catch {
        return;
      }
    }

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
          explain,
        },
      }
    )
      .then((result) => {
        this.results = result;
        this.isCachedResult = false;
        if (!result.success) {
          this.showResults = false;
          return;
        }
        this.showResults = true;
        this.initView();
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
