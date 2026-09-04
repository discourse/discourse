import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import AdminSectionLandingItem from "discourse/admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "discourse/admin/components/admin-section-landing-wrapper";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { clipboardCopy } from "discourse/lib/utilities";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { eq, not, notEq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DMultiSelect from "discourse/ui-kit/d-multi-select";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import { i18n } from "discourse-i18n";

const CLIENT_PRESETS = {
  codex: {
    name: "Codex",
    client_id: "codex",
    redirect_uris: "http://127.0.0.1/callback",
  },
  claude_code: {
    name: "Claude Code",
    client_id: "claude-code",
    redirect_uris: "http://localhost:8080/callback",
  },
  mcp_inspector: {
    name: "MCP Inspector",
    client_id: "mcp-inspector",
    redirect_uris:
      "http://localhost:6274/oauth/callback\nhttp://127.0.0.1:6276/oauth/callback",
  },
  visual_studio_code: {
    name: "Visual Studio Code",
    client_id: "visual-studio-code",
    redirect_uris: "https://vscode.dev/redirect",
  },
  custom: { name: "", client_id: "", redirect_uris: "" },
};

function listValue(value) {
  return Array.isArray(value) ? value.join(", ") : value || "";
}

function normalizeList(value) {
  if (Array.isArray(value)) {
    return value;
  }

  return (value || "")
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function mcpValue(group, value) {
  return i18n(`admin.config.mcp.values.${group}.${value}`);
}

export default class AdminMcp extends Component {
  @service a11y;
  @service dialog;
  @service router;
  @service site;
  @service toasts;

  @tracked primitiveFilter = "";
  @tracked primitiveGroupBy = "scope";
  @tracked selectedPrimitiveGroup = "all";
  @tracked primitiveRisk = "all";
  @tracked primitiveState = "all";
  @tracked primitiveEnabledStates;
  @tracked authorizationFilter = "";
  @tracked clientFilter = "";
  @tracked activityFilter = "";
  @tracked activityOutcome = "all";
  @tracked primitiveFormApi;
  @tracked saving = false;
  @tracked clients;
  @tracked clientRecord;
  @tracked clientNextCursor;
  @tracked clientLoading = false;
  @tracked selectedClientPresetId;
  @tracked primitiveRecords;
  @tracked updatingPrimitiveId;
  @tracked authorizations;
  @tracked authorizationNextCursor;
  @tracked authorizationLoading = false;
  @tracked activity;
  @tracked activityMetrics;
  @tracked activityNextCursor;
  @tracked activityLoading = false;
  @tracked accessRules;
  @tracked accessFormData;
  @tracked editingAccessRule;

  primitiveFilterFormData = {
    primitiveFilter: "",
    primitiveGroupBy: "scope",
    primitiveRisk: "all",
    primitiveState: "all",
  };
  clientFilterFormData = { clientFilter: "" };
  authorizationFilterFormData = { authorizationFilter: "" };
  activityFilterFormData = { activityFilter: "", activityOutcome: "all" };
  clientPresetIds = Object.keys(CLIENT_PRESETS);
  clientRequestId = 0;
  authorizationRequestId = 0;
  activityRequestId = 0;

  constructor() {
    super(...arguments);
    const model = this.args.model || {};
    this.clients = model.clients || model.oauth_clients;
    this.clientNextCursor = model.meta?.next_cursor;
    this.clientRecord = model.client;
    this.primitiveRecords = model.primitives;
    this.primitiveEnabledStates = new Map(
      (model.primitives || []).map((primitive) => [
        primitive.id,
        Boolean(primitive.enabled),
      ])
    );
    this.authorizations = model.authorizations;
    this.authorizationNextCursor = model.meta?.next_cursor;
    this.activity = model.activity || model.events;
    this.activityMetrics = model.metrics;
    this.activityNextCursor = model.meta?.next_cursor;
    this.accessRules = model.access_rules || [];
    if (this.args.section === "access-new") {
      this.accessFormData = {
        group_ids: [],
        scopes: this.accessScopeSelections([]),
      };
    } else if (this.args.section === "access-edit") {
      this.editingAccessRule = model.access_rule;
      this.accessFormData = {
        group_ids: [model.access_rule.group_id.toString()],
        scopes: this.accessScopeSelections(model.access_rule.scopes),
      };
    }
  }

  get model() {
    return this.args.model || {};
  }

  get groupOptions() {
    return (this.site.groups || []).map((group) => ({
      id: group.id.toString(),
      name: group.name,
    }));
  }

  get primitives() {
    return this.primitiveRecords || this.model.primitives || [];
  }

  get catalog() {
    return this.model.catalog || {};
  }

  get metrics() {
    return this.activityMetrics || this.model.metrics || {};
  }

  get setupChecklist() {
    return this.model.setup_checklist || [];
  }

  get showSetupChecklist() {
    return this.setupChecklist.some((item) => !item.complete);
  }

  get warnings() {
    return this.model.warnings || [];
  }

  get client() {
    return this.clientRecord || this.model.client || this.model;
  }

  get filteredPrimitives() {
    const filter = (this.primitiveFilter || "").trim().toLowerCase();

    return this.primitives.filter((primitive) => {
      const matchesText =
        !filter ||
        [
          primitive.id,
          primitive.name,
          primitive.title,
          primitive.description,
          primitive.provider,
          ...(primitive.required_scopes || []),
        ]
          .filter(Boolean)
          .join(" ")
          .toLowerCase()
          .includes(filter);
      const matchesGroup =
        this.selectedPrimitiveGroup === "all" ||
        this.primitiveGroupValues(primitive).includes(
          this.selectedPrimitiveGroup
        );
      const matchesRisk =
        this.primitiveRisk === "all" || primitive.risk === this.primitiveRisk;
      const matchesState =
        this.primitiveState === "all" ||
        (this.primitiveState === "enabled" && primitive.enabled) ||
        (this.primitiveState === "disabled" && !primitive.enabled) ||
        (this.primitiveState === "unavailable" && !primitive.available) ||
        (this.primitiveState === "blocked" && primitive.emergency_blocked);

      return matchesText && matchesGroup && matchesRisk && matchesState;
    });
  }

  get primitiveProviders() {
    return [
      ...new Set(
        this.primitives.map((primitive) => primitive.provider).filter(Boolean)
      ),
    ];
  }

  get primitiveKinds() {
    return [
      ...new Set(
        this.primitives.map((primitive) => primitive.kind).filter(Boolean)
      ),
    ];
  }

  get primitiveRisks() {
    return [
      "all",
      ...new Set(
        this.primitives.map((primitive) => primitive.risk).filter(Boolean)
      ),
    ];
  }

  get primitiveStates() {
    return ["all", "enabled", "disabled", "unavailable", "blocked"];
  }

  get primitiveGroupByOptions() {
    return ["scope", "provider", "kind"];
  }

  get primitiveGroupIds() {
    switch (this.primitiveGroupBy) {
      case "provider":
        return this.primitiveProviders;
      case "kind":
        return this.primitiveKinds;
      default:
        return this.scopeOptions
          .filter((scope) => scope.primitiveCount > 0)
          .map((scope) => scope.id);
    }
  }

  get primitiveGroups() {
    return ["all", ...this.primitiveGroupIds].map((id) => {
      const primitives =
        id === "all"
          ? this.primitives
          : this.primitives.filter((primitive) =>
              this.primitiveGroupValues(primitive).includes(id)
            );

      return {
        id,
        label:
          id === "all"
            ? i18n("admin.config.mcp.primitives.all_primitives")
            : this.primitiveGroupLabel(id),
        enabled: primitives.filter((primitive) =>
          this.primitiveEnabledStates.get(primitive.id)
        ).length,
        total: primitives.length,
      };
    });
  }

  get selectedPrimitiveGroupDetails() {
    return (
      this.primitiveGroups.find(
        (group) => group.id === this.selectedPrimitiveGroup
      ) || this.primitiveGroups[0]
    );
  }

  get scopeOptions() {
    const counts = new Map();
    this.primitives.forEach((primitive) => {
      (primitive.required_scopes || []).forEach((scope) => {
        counts.set(scope, (counts.get(scope) || 0) + 1);
      });
    });

    const scopes = this.model.available_scopes || [...counts.keys()];
    return scopes.map((scope) => ({
      id: scope,
      name: scope,
      primitiveCount: counts.get(scope) || 0,
      preventRemoval: scope === this.model.initial_scope,
    }));
  }

  accessScopeSelections(scopes) {
    const scopeIds = new Set(scopes || []);
    if (this.model.initial_scope) {
      scopeIds.add(this.model.initial_scope);
    }
    return this.scopeSelections([...scopeIds]);
  }

  scopeSelections(scopes) {
    const options = new Map(
      this.scopeOptions.map((option) => [option.id, option])
    );
    return (scopes || []).map(
      (scope) =>
        options.get(scope) || {
          id: scope,
          name: scope,
          primitiveCount: 0,
        }
    );
  }

  get groupChooserOptions() {
    return { maximum: 1 };
  }

  get availableAccessGroups() {
    const usedGroupIds = new Set(
      this.accessRules.map((rule) => rule.group_id.toString())
    );
    return this.groupOptions.filter((group) => !usedGroupIds.has(group.id));
  }

  get newClientFormData() {
    return { ...CLIENT_PRESETS[this.selectedClientPresetId] };
  }

  get primitiveFormData() {
    return this.primitives.reduce((data, primitive) => {
      data[this.primitiveFieldName(primitive)] = Boolean(primitive.enabled);
      return data;
    }, {});
  }

  get hasPrimitiveChanges() {
    return this.primitives.some(
      (primitive) =>
        this.primitiveEnabledStates.get(primitive.id) !==
        Boolean(primitive.enabled)
    );
  }

  get clientRecords() {
    return this.clients || this.model.clients || this.model.oauth_clients || [];
  }

  get hasClients() {
    return this.clientRecords.length > 0 || this.clientFilter.trim().length > 0;
  }

  get filteredClients() {
    return this.clientRecords;
  }

  get filteredAuthorizations() {
    return this.authorizations || this.model.authorizations || [];
  }

  get canLoadMoreClients() {
    return Boolean(this.clientNextCursor);
  }

  get canLoadMoreAuthorizations() {
    return Boolean(this.authorizationNextCursor);
  }

  get activityOutcomes() {
    return ["all", "success", "error", "rate_limited"];
  }

  get canLoadMoreActivity() {
    return Boolean(this.activityNextCursor);
  }

  primitiveFieldName(primitive) {
    return primitive.field_name;
  }

  primitiveGroupValues(primitive) {
    switch (this.primitiveGroupBy) {
      case "provider":
        return primitive.provider ? [primitive.provider] : [];
      case "kind":
        return primitive.kind ? [primitive.kind] : [];
      default:
        return primitive.required_scopes || [];
    }
  }

  primitiveGroupLabel(id) {
    return this.primitiveGroupBy === "kind"
      ? mcpValue("primitive_kind", id)
      : id;
  }

  announcePrimitiveResults() {
    this.a11y.announce(
      i18n("admin.config.mcp.primitives.results_count", {
        visible: this.filteredPrimitives.length,
        total: this.primitives.length,
      }),
      "polite"
    );
  }

  @action
  async loadScopeOptions(filter) {
    const query = filter.trim().toLowerCase();
    return this.scopeOptions.filter((scope) =>
      scope.name.toLowerCase().includes(query)
    );
  }

  @action
  updateFilter(name, value) {
    switch (name) {
      case "primitiveFilter":
        this.selectedPrimitiveGroup = "all";
        this.primitiveFilter = value || "";
        this.announcePrimitiveResults();
        break;
      case "primitiveGroupBy":
        this.primitiveGroupBy = value;
        this.selectedPrimitiveGroup = "all";
        this.announcePrimitiveResults();
        break;
      case "primitiveRisk":
        this.primitiveRisk = value;
        this.announcePrimitiveResults();
        break;
      case "primitiveState":
        this.primitiveState = value;
        this.announcePrimitiveResults();
        break;
      case "clientFilter":
        this.clientFilter = value || "";
        discourseDebounce(this, this.reloadClients, INPUT_DELAY);
        break;
      case "authorizationFilter":
        this.authorizationFilter = value || "";
        discourseDebounce(this, this.reloadAuthorizations, INPUT_DELAY);
        break;
      case "activityFilter":
        this.activityFilter = value || "";
        discourseDebounce(this, this.reloadActivity, INPUT_DELAY);
        break;
      case "activityOutcome":
        this.activityOutcome = value;
        discourseDebounce(this, this.reloadActivity, 0);
        break;
    }
  }

  @action
  registerPrimitiveForm(api) {
    this.primitiveFormApi = api;
  }

  @action
  shouldConfirmPrimitiveChanges() {
    return this.hasPrimitiveChanges;
  }

  @action
  positionPrimitiveActions([entry]) {
    const sectionElement = entry.target.closest(
      ".admin-mcp__primitives-section"
    );
    const formElement = sectionElement?.querySelector(
      ".admin-mcp__primitive-selection-form"
    );
    const actionsElement = formElement?.querySelector(".form-kit__actions");

    if (!formElement || !actionsElement) {
      return;
    }

    const { width } = formElement.getBoundingClientRect();
    const { height } = actionsElement.getBoundingClientRect();
    actionsElement.style.width = `${width}px`;
    formElement.style.setProperty(
      "--mcp-primitive-actions-height",
      `${height}px`
    );
  }

  @action
  selectPrimitiveGroup(groupId) {
    this.selectedPrimitiveGroup = groupId;
    this.announcePrimitiveResults();
  }

  @action
  updatePrimitiveEnabled(primitive, event) {
    const enabled = event.target.checked;
    const states = new Map(this.primitiveEnabledStates);
    states.set(primitive.id, enabled);
    this.primitiveEnabledStates = states;
  }

  @action
  selectVisiblePrimitives(enabled) {
    const states = new Map(this.primitiveEnabledStates);
    this.filteredPrimitives.forEach((primitive) => {
      this.primitiveFormApi?.set(this.primitiveFieldName(primitive), enabled);
      states.set(primitive.id, enabled);
    });
    this.primitiveEnabledStates = states;
  }

  @action
  async saveAccessRule(data) {
    const groupId = this.editingAccessRule?.group_id || data.group_ids?.[0];
    this.saving = true;
    try {
      const result = await ajax(`/admin/mcp/access/${groupId}.json`, {
        type: "PUT",
        data: {
          scopes: (data.scopes || []).map((scope) => scope.id),
        },
      });
      this.accessRules = result.access_rules;
      this.model.access_rules = result.access_rules;
      this.toasts.success({
        duration: "short",
        data: { message: i18n("admin.config.mcp.access.saved") },
      });
      this.router.transitionTo("adminConfig.mcp.access");
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  deleteAccessRule(rule) {
    this.dialog.confirm({
      message: i18n("admin.config.mcp.access.confirm_delete", {
        group: rule.group_name,
      }),
      didConfirm: async () => {
        try {
          await ajax(`/admin/mcp/access/${rule.group_id}.json`, {
            type: "DELETE",
          });
          this.accessRules = this.accessRules.filter(
            (item) => item.group_id !== rule.group_id
          );
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  async savePrimitives(data) {
    this.saving = true;
    try {
      const enabledPrimitives = Object.entries(data)
        .filter(([, enabled]) => enabled)
        .map(
          ([field]) =>
            this.primitives.find((primitive) => primitive.field_name === field)
              ?.id
        )
        .filter(Boolean);
      await ajax("/admin/mcp/capabilities.json", {
        type: "PUT",
        data: { primitive_ids: enabledPrimitives },
      });
      const enabledPrimitiveIds = new Set(enabledPrimitives);
      this.primitiveRecords = this.primitives.map((primitive) => ({
        ...primitive,
        enabled: enabledPrimitiveIds.has(primitive.id),
      }));
      this.toasts.success({
        duration: "short",
        data: { message: i18n("admin.config.mcp.primitives_saved") },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  async #setPrimitiveBlocked(primitive, blocked) {
    this.updatingPrimitiveId = primitive.id;
    try {
      await ajax("/admin/mcp/capabilities/emergency-block.json", {
        type: "PUT",
        data: { primitive_id: primitive.id, blocked },
      });
      this.primitiveRecords = this.primitiveRecords.map((item) =>
        item.id === primitive.id
          ? { ...item, emergency_blocked: blocked }
          : item
      );
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            blocked
              ? "admin.config.mcp.primitive_blocked"
              : "admin.config.mcp.primitive_unblocked",
            { name: primitive.title || primitive.name }
          ),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.updatingPrimitiveId = null;
    }
  }

  @action
  togglePrimitiveEmergencyBlock(primitive) {
    const blocked = !primitive.emergency_blocked;
    const updateBlock = () => this.#setPrimitiveBlocked(primitive, blocked);

    if (blocked) {
      this.dialog.confirm({
        message: i18n("admin.config.mcp.confirm_emergency_block", {
          name: primitive.title || primitive.name,
        }),
        didConfirm: updateBlock,
      });
    } else {
      updateBlock();
    }
  }

  @action
  copyEndpoint() {
    if (clipboardCopy(this.model.endpoint)) {
      this.toasts.success({
        duration: "short",
        data: { message: i18n("admin.config.mcp.endpoint_copied") },
      });
    }
  }

  @action
  async createClient(data) {
    this.saving = true;
    try {
      const result = await ajax("/admin/mcp/clients.json", {
        type: "POST",
        data: {
          client: {
            name: data.name,
            client_id: data.client_id,
            redirect_uris: normalizeList(data.redirect_uris),
          },
        },
      });
      this.toasts.success({
        duration: "short",
        data: { message: i18n("admin.config.mcp.clients.created") },
      });
      this.router.transitionTo(
        "adminConfig.mcp.clients.show",
        result.client.id
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  resetClientPreset() {
    this.selectedClientPresetId = null;
  }

  @action
  selectClientPreset(preset) {
    this.selectedClientPresetId = preset;
  }

  @action
  async toggleClientBlock(client) {
    const blocked = !client.blocked;
    const updateBlock = () =>
      ajax(`/admin/mcp/clients/${client.id}/block.json`, {
        type: "PUT",
        data: { blocked },
      }).then((result) => {
        const updatedClient = result.client || {
          ...client,
          blocked,
          trust_state: blocked ? "blocked" : "approved",
        };
        this.clientRecord = updatedClient;
        this.clients = this.clients?.map((item) =>
          item.id === client.id ? updatedClient : item
        );
      });

    if (blocked) {
      this.dialog.confirm({
        message: i18n("admin.config.mcp.confirm_block_client", {
          name: client.name,
        }),
        didConfirm: updateBlock,
      });
    } else {
      await updateBlock().catch(popupAjaxError);
    }
  }

  @action
  async refreshClient(client) {
    try {
      const result = await ajax(
        `/admin/mcp/clients/${client.id}/refresh.json`,
        {
          type: "POST",
        }
      );
      const updatedClient = result.client || result;
      this.clientRecord = updatedClient;
      this.clients = this.clients?.map((item) =>
        item.id === client.id ? updatedClient : item
      );
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  revokeAuthorization(authorization) {
    this.dialog.confirm({
      message: i18n("admin.config.mcp.confirm_revoke_authorization", {
        name: authorization.client_name,
      }),
      didConfirm: async () => {
        try {
          await ajax(`/admin/mcp/authorizations/${authorization.id}.json`, {
            type: "DELETE",
          });
          this.authorizations = this.authorizations.map((item) =>
            item.id === authorization.id ? { ...item, status: "revoked" } : item
          );
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  reloadClients() {
    return this.loadClients({ append: false });
  }

  @action
  loadMoreClients() {
    if (!this.canLoadMoreClients || this.clientLoading) {
      return;
    }

    return this.loadClients({ append: true });
  }

  async loadClients({ append }) {
    const cursor = append ? this.clientNextCursor : null;
    const requestId = this.clientRequestId + 1;
    this.clientRequestId = requestId;
    this.clientLoading = true;

    try {
      const result = await ajax("/admin/mcp/clients.json", {
        data: this.recordRequestData(this.clientFilter, cursor),
      });
      if (requestId !== this.clientRequestId) {
        return;
      }

      const clients = result.clients || [];
      this.clients = append ? [...this.clientRecords, ...clients] : clients;
      this.clientNextCursor =
        result.meta?.next_cursor || result.next_cursor || null;
    } catch (error) {
      if (requestId === this.clientRequestId) {
        popupAjaxError(error);
      }
    } finally {
      if (requestId === this.clientRequestId) {
        this.clientLoading = false;
      }
    }
  }

  @action
  reloadAuthorizations() {
    return this.loadAuthorizations({ append: false });
  }

  @action
  loadMoreAuthorizations() {
    if (!this.canLoadMoreAuthorizations || this.authorizationLoading) {
      return;
    }

    return this.loadAuthorizations({ append: true });
  }

  async loadAuthorizations({ append }) {
    const cursor = append ? this.authorizationNextCursor : null;
    const requestId = this.authorizationRequestId + 1;
    this.authorizationRequestId = requestId;
    this.authorizationLoading = true;

    try {
      const result = await ajax("/admin/mcp/authorizations.json", {
        data: this.recordRequestData(this.authorizationFilter, cursor),
      });
      if (requestId !== this.authorizationRequestId) {
        return;
      }

      const authorizations = result.authorizations || [];
      this.authorizations = append
        ? [...this.filteredAuthorizations, ...authorizations]
        : authorizations;
      this.authorizationNextCursor =
        result.meta?.next_cursor || result.next_cursor || null;
    } catch (error) {
      if (requestId === this.authorizationRequestId) {
        popupAjaxError(error);
      }
    } finally {
      if (requestId === this.authorizationRequestId) {
        this.authorizationLoading = false;
      }
    }
  }

  recordRequestData(filter, cursor) {
    const data = {};
    const normalizedFilter = filter.trim();
    if (normalizedFilter) {
      data.filter = normalizedFilter;
    }
    if (cursor) {
      data.cursor = cursor;
    }
    return data;
  }

  @action
  reloadActivity() {
    return this.loadActivity({ append: false });
  }

  @action
  loadMoreActivity() {
    if (!this.canLoadMoreActivity || this.activityLoading) {
      return;
    }

    return this.loadActivity({ append: true });
  }

  async loadActivity({ append }) {
    const cursor = append ? this.activityNextCursor : null;
    const requestId = this.activityRequestId + 1;
    this.activityRequestId = requestId;
    this.activityLoading = true;

    try {
      const result = await ajax("/admin/mcp/activity.json", {
        data: this.activityRequestData(cursor),
      });
      if (requestId !== this.activityRequestId) {
        return;
      }

      const activity = result.activity || result.events || [];
      this.activity = append ? [...this.activity, ...activity] : activity;
      this.activityNextCursor = result.meta?.next_cursor || result.next_cursor;
      this.activityMetrics = result.metrics || this.activityMetrics;
    } catch (error) {
      if (requestId === this.activityRequestId) {
        popupAjaxError(error);
      }
    } finally {
      if (requestId === this.activityRequestId) {
        this.activityLoading = false;
      }
    }
  }

  activityRequestData(cursor) {
    const data = {};
    const filter = this.activityFilter.trim();
    if (filter) {
      data.filter = filter;
    }
    if (this.activityOutcome !== "all") {
      data.outcome = this.activityOutcome;
    }
    if (cursor) {
      data.cursor = cursor;
    }
    return data;
  }

  <template>
    {{#if (eq @section "overview")}}
      <DPageSubheader
        @titleLabel={{i18n "admin.config.mcp.overview.title"}}
        @descriptionLabel={{i18n "admin.config.mcp.overview.description"}}
      />
      <div class="admin-mcp__overview-grid">
        <AdminConfigAreaCard
          @heading="admin.config.mcp.overview.endpoint_title"
          class="admin-mcp__endpoint-card"
        >
          <:content>
            <div class="admin-mcp__endpoint">
              <code>{{@model.endpoint}}</code>
              <DButton
                @action={{this.copyEndpoint}}
                @icon="copy"
                @title="admin.config.mcp.copy_endpoint"
                class="btn-transparent"
              />
            </div>
            <dl class="admin-mcp__summary-list">
              <div><dt>{{i18n "admin.config.mcp.overview.protocol"}}</dt><dd
                >{{@model.protocol_version}}</dd></div>
              <div><dt>{{i18n
                    "admin.config.mcp.overview.server_version"
                  }}</dt><dd>{{@model.server_version}}</dd></div>
              <div><dt>{{i18n "admin.config.mcp.overview.status"}}</dt><dd
                >{{mcpValue "server_status" @model.status}}</dd></div>
            </dl>
          </:content>
        </AdminConfigAreaCard>

        <AdminConfigAreaCard @heading="admin.config.mcp.overview.catalog_title">
          <:content>
            <dl class="admin-mcp__metric-grid">
              <div><dt>{{i18n "admin.config.mcp.overview.tools"}}</dt><dd
                >{{this.catalog.tools}}</dd></div>
              <div><dt>{{i18n "admin.config.mcp.overview.resources"}}</dt><dd
                >{{this.catalog.resources}}</dd></div>
              <div><dt>{{i18n "admin.config.mcp.overview.prompts"}}</dt><dd
                >{{this.catalog.prompts}}</dd></div>
              <div><dt>{{i18n "admin.config.mcp.overview.schema_size"}}</dt><dd
                >{{i18n
                    "admin.config.mcp.overview.schema_size_value"
                    bytes=this.catalog.schema_bytes
                  }}</dd></div>
            </dl>
          </:content>
        </AdminConfigAreaCard>

        <AdminConfigAreaCard
          @heading="admin.config.mcp.overview.activity_title"
          class="admin-mcp__usage"
        >
          <:content>
            <dl class="admin-mcp__metric-grid">
              <div><dt>{{i18n
                    "admin.config.mcp.overview.approved_oauth_clients"
                  }}</dt><dd>{{this.metrics.approved_oauth_clients}}</dd></div>
              <div><dt>{{i18n
                    "admin.config.mcp.overview.authorizations"
                  }}</dt><dd>{{this.metrics.authorizations}}</dd></div>
              <div><dt>{{i18n "admin.config.mcp.overview.tokens"}}</dt><dd
                >{{this.metrics.tokens}}</dd></div>
              <div><dt>{{i18n "admin.config.mcp.overview.errors"}}</dt><dd
                >{{this.metrics.errors}}</dd></div>
            </dl>
          </:content>
        </AdminConfigAreaCard>

        {{#if this.showSetupChecklist}}
          <AdminConfigAreaCard
            @heading="admin.config.mcp.overview.setup_title"
            class="admin-mcp__setup"
          >
            <:content>
              <ol class="admin-mcp__checklist">
                {{#each this.setupChecklist as |item|}}
                  <li class={{if item.complete "is-complete"}}>
                    {{dIcon (if item.complete "circle-check" "circle")}}
                    <span>{{item.label}}</span>
                  </li>
                {{/each}}
              </ol>
            </:content>
          </AdminConfigAreaCard>
        {{/if}}
      </div>

      {{#if this.warnings.length}}
        <section
          class="admin-mcp__warnings"
          aria-labelledby="mcp-warnings-title"
        >
          <h2 id="mcp-warnings-title">{{i18n
              "admin.config.mcp.overview.warnings_title"
            }}</h2>
          <ul>
            {{#each this.warnings as |warning|}}<li>{{warning}}</li>{{/each}}
          </ul>
        </section>
      {{/if}}
    {{else if (eq @section "access")}}
      <section class="admin-mcp__access-section">
        <DPageSubheader
          @titleLabel={{i18n "admin.config.mcp.access.title"}}
          @descriptionLabel={{i18n "admin.config.mcp.access.description"}}
        >
          <:actions as |actions|>
            <actions.Primary
              @route="adminConfig.mcp.access.new"
              @label="admin.config.mcp.access.add"
            />
          </:actions>
        </DPageSubheader>

        <table class="d-table admin-mcp__access-table">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__cell --overview">{{i18n
                  "admin.config.mcp.access.groups"
                }}</th>
              <th class="d-table__cell --detail">{{i18n
                  "admin.config.mcp.access.scopes"
                }}</th>
              <th class="d-table__cell --controls"><span class="sr-only">{{i18n
                    "admin.config.mcp.access.edit"
                  }}</span></th>
              <th class="d-table__cell --controls"><span class="sr-only">{{i18n
                    "admin.config.mcp.access.delete"
                  }}</span></th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each this.accessRules as |rule|}}
              <tr
                class="d-table__row admin-mcp__access-row"
                data-group-id={{rule.group_id}}
              >
                <td class="d-table__cell --overview">
                  <span
                    class="d-table__overview-name"
                  >{{rule.group_name}}</span>
                  {{#if rule.pre_registered}}
                    <small>{{i18n
                        "admin.config.mcp.access.admins_description"
                      }}</small>
                  {{/if}}
                </td>
                <td class="d-table__cell --detail">
                  <div class="d-table__mobile-label">{{i18n
                      "admin.config.mcp.access.scopes"
                    }}</div>
                  <ul class="admin-mcp__access-scopes">
                    {{#each rule.scopes as |scope|}}<li><code
                        >{{scope}}</code></li>{{/each}}
                  </ul>
                </td>
                <td class="d-table__cell --controls">
                  <DButton
                    @route="adminConfig.mcp.access.edit"
                    @routeModels={{array rule.group_id}}
                    @icon="pencil"
                    @label="admin.config.mcp.access.edit"
                    class="btn-small admin-mcp__edit-access-rule"
                  />
                </td>
                <td class="d-table__cell --controls">
                  {{#if rule.deletable}}
                    <DButton
                      @action={{fn this.deleteAccessRule rule}}
                      @icon="trash-can"
                      @title="admin.config.mcp.access.delete"
                      class="btn-danger btn-small admin-mcp__delete-access-rule"
                    />
                  {{/if}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </section>

    {{else if (or (eq @section "access-new") (eq @section "access-edit"))}}
      <BackButton
        @route="adminConfig.mcp.access"
        @label="admin.config.mcp.access.back"
      />
      <AdminConfigAreaCard
        @heading={{if
          this.editingAccessRule
          "admin.config.mcp.access.edit_title"
          "admin.config.mcp.access.new_title"
        }}
        class="admin-mcp__form-card"
      >
        <:content>
          <Form
            @data={{this.accessFormData}}
            @onSubmit={{this.saveAccessRule}}
            @isLoading={{this.saving}}
            class="admin-mcp__access-form"
            as |form|
          >
            {{#if this.editingAccessRule}}
              <div class="form-kit__field">
                <span class="form-kit__label">{{i18n
                    "admin.config.mcp.access.group"
                  }}</span>
                <strong>{{this.editingAccessRule.group_name}}</strong>
              </div>
            {{else}}
              <form.Field
                @name="group_ids"
                @title={{i18n "admin.config.mcp.access.group"}}
                @validation="required"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <GroupChooser
                    @content={{this.availableAccessGroups}}
                    @value={{field.value}}
                    @onChange={{field.set}}
                    @options={{this.groupChooserOptions}}
                  />
                </field.Control>
              </form.Field>
            {{/if}}
            <form.Field
              @name="scopes"
              @title={{i18n "admin.config.mcp.access.scopes"}}
              @description={{i18n "admin.config.mcp.access.scopes_description"}}
              @validation="required"
              @format="full"
              @type="custom"
              as |field|
            >
              <field.Control>
                <DMultiSelect
                  id={{field.id}}
                  @selection={{field.value}}
                  @loadFn={{this.loadScopeOptions}}
                  @onChange={{field.set}}
                  @label={{i18n "admin.config.mcp.access.scopes_placeholder"}}
                  @contentClass="admin-mcp__scope-select-content"
                  class="admin-mcp__scope-select"
                >
                  <:selection as |scope|>{{scope.name}}</:selection>
                  <:result as |scope|>
                    <span class="admin-mcp__scope-option">
                      <span>{{scope.name}}</span>
                      <small>{{i18n
                          "admin.config.mcp.access.scope_primitives"
                          count=scope.primitiveCount
                        }}</small>
                    </span>
                  </:result>
                </DMultiSelect>
              </field.Control>
            </form.Field>
            <div class="admin-mcp__access-form-actions">
              <form.Submit @label="admin.config.mcp.access.save" />
            </div>
          </Form>
        </:content>
      </AdminConfigAreaCard>

    {{else if (eq @section "primitives")}}
      <DPageSubheader
        @titleLabel={{i18n "admin.config.mcp.capabilities.title"}}
        @descriptionLabel={{i18n "admin.config.mcp.capabilities.description"}}
      />
      <div
        class="admin-mcp__primitives-section"
        {{dOnResize this.positionPrimitiveActions}}
      >
        <p class="admin-mcp__primitives-description">{{i18n
            "admin.config.mcp.primitives.picker_description"
          }}</p>
        <Form
          @data={{this.primitiveFilterFormData}}
          @onSet={{this.updateFilter}}
          class="admin-mcp__primitive-filters"
          as |form|
        >
          <form.Field
            @name="primitiveFilter"
            @title={{i18n "admin.config.mcp.primitives.search_placeholder"}}
            @showTitle={{false}}
            @showOptional={{false}}
            @format="full"
            @type="input"
            class="admin-mcp__filter-search"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                "admin.config.mcp.primitives.search_placeholder"
              }}
            />
          </form.Field>
          <form.Field
            @name="primitiveGroupBy"
            @title={{i18n "admin.config.mcp.primitives.group_by"}}
            @showTitle={{false}}
            @showOptional={{false}}
            @format="full"
            @type="select"
            as |field|
          >
            <field.Control
              @includeNone={{false}}
              aria-label={{i18n "admin.config.mcp.primitives.group_by"}}
              as |select|
            >
              {{#each this.primitiveGroupByOptions as |groupBy|}}
                <select.Option @value={{groupBy}}>{{i18n
                    (concat
                      "admin.config.mcp.primitives.group_by_options." groupBy
                    )
                  }}</select.Option>
              {{/each}}
            </field.Control>
          </form.Field>
          <form.Field
            @name="primitiveRisk"
            @title={{i18n "admin.config.mcp.primitives.risk"}}
            @showTitle={{false}}
            @showOptional={{false}}
            @format="full"
            @type="select"
            class="admin-mcp__filter-impact"
            as |field|
          >
            <field.Control
              @includeNone={{false}}
              aria-label={{i18n "admin.config.mcp.primitives.risk"}}
              as |select|
            >
              {{#each this.primitiveRisks as |risk|}}
                <select.Option @value={{risk}}>{{mcpValue
                    "primitive_risk"
                    risk
                  }}</select.Option>
              {{/each}}
            </field.Control>
          </form.Field>
          <form.Field
            @name="primitiveState"
            @title={{i18n "admin.config.mcp.primitives.state"}}
            @showTitle={{false}}
            @showOptional={{false}}
            @format="full"
            @type="select"
            as |field|
          >
            <field.Control
              @includeNone={{false}}
              aria-label={{i18n "admin.config.mcp.primitives.state"}}
              as |select|
            >
              {{#each this.primitiveStates as |state|}}
                <select.Option @value={{state}}>{{mcpValue
                    "primitive_state"
                    state
                  }}</select.Option>
              {{/each}}
            </field.Control>
          </form.Field>
        </Form>
        <Form
          @data={{this.primitiveFormData}}
          @onRegisterApi={{this.registerPrimitiveForm}}
          @onSubmit={{this.savePrimitives}}
          @onDirtyCheck={{this.shouldConfirmPrimitiveChanges}}
          @isLoading={{this.saving}}
          class={{dConcatClass
            "admin-mcp__primitive-selection-form"
            (if this.hasPrimitiveChanges "has-floating-actions")
          }}
          as |form|
        >
          <div class="admin-mcp__primitive-browser">
            <nav
              class="admin-mcp__primitive-groups"
              aria-label={{i18n "admin.config.mcp.primitives.groups_label"}}
            >
              <ul class="admin-mcp__primitive-group-list">
                {{#each this.primitiveGroups as |group|}}
                  <li>
                    <button
                      type="button"
                      class={{dConcatClass
                        "admin-mcp__primitive-group"
                        (if
                          (eq group.id this.selectedPrimitiveGroup)
                          "is-selected"
                        )
                      }}
                      data-primitive-group-id={{group.id}}
                      aria-pressed={{eq group.id this.selectedPrimitiveGroup}}
                      {{on "click" (fn this.selectPrimitiveGroup group.id)}}
                    >
                      <span>{{group.label}}</span>
                      <small>{{i18n
                          "admin.config.mcp.primitives.group_count"
                          enabled=group.enabled
                          total=group.total
                        }}</small>
                    </button>
                  </li>
                {{/each}}
              </ul>
            </nav>
            <section
              class="admin-mcp__primitive-panel"
              aria-labelledby="mcp-primitive-group-title"
            >
              <header class="admin-mcp__primitive-panel-header">
                <h3
                  id="mcp-primitive-group-title"
                >{{this.selectedPrimitiveGroupDetails.label}}</h3>
                <p class="admin-mcp__results-count">{{i18n
                    "admin.config.mcp.primitives.results_count"
                    visible=this.filteredPrimitives.length
                    total=this.primitives.length
                  }}</p>
                <div class="admin-mcp__primitive-group-actions">
                  <DButton
                    @action={{fn this.selectVisiblePrimitives true}}
                    @label="admin.config.mcp.primitives.enable_visible"
                    class="btn-default btn-small"
                  />
                  <DButton
                    @action={{fn this.selectVisiblePrimitives false}}
                    @label="admin.config.mcp.primitives.disable_visible"
                    class="btn-default btn-small"
                  />
                </div>
              </header>
              <div class="admin-mcp__primitive-list">
                {{#each this.filteredPrimitives as |primitive|}}
                  <article
                    class="admin-mcp__primitive"
                    data-primitive-id={{primitive.id}}
                  >
                    <form.Field
                      @name={{primitive.field_name}}
                      @title={{primitive.title}}
                      @showTitle={{false}}
                      @type="checkbox"
                      as |field|
                    >
                      <field.Control
                        disabled={{or
                          (not primitive.available)
                          primitive.emergency_blocked
                        }}
                        {{on
                          "change"
                          (fn this.updatePrimitiveEnabled primitive)
                        }}
                      >{{primitive.description}}</field.Control>
                    </form.Field>
                    <dl class="admin-mcp__primitive-meta">
                      <div><dt>{{i18n
                            "admin.config.mcp.primitives.provider"
                          }}</dt><dd>{{primitive.provider}}</dd></div>
                      <div><dt>{{i18n
                            "admin.config.mcp.primitives.kind"
                          }}</dt><dd>{{mcpValue
                            "primitive_kind"
                            primitive.kind
                          }}</dd></div>
                      <div><dt>{{i18n
                            "admin.config.mcp.primitives.risk"
                          }}</dt><dd>{{mcpValue
                            "primitive_risk"
                            primitive.risk
                          }}</dd></div>
                      <div><dt>{{i18n
                            "admin.config.mcp.primitives.scopes"
                          }}</dt><dd>{{listValue
                            primitive.required_scopes
                          }}</dd></div>
                    </dl>
                    {{#unless primitive.available}}<p
                        class="admin-mcp__unavailable"
                      >{{primitive.unavailable_reason}}</p>{{/unless}}
                    {{#if primitive.emergency_blocked}}<p
                        class="admin-mcp__unavailable"
                      >{{i18n
                          "admin.config.mcp.primitives.emergency_blocked"
                        }}</p>{{/if}}
                    <div class="admin-mcp__primitive-actions">
                      <DButton
                        @action={{fn
                          this.togglePrimitiveEmergencyBlock
                          primitive
                        }}
                        @title={{if
                          primitive.emergency_blocked
                          "admin.config.mcp.actions.unblock_primitive"
                          "admin.config.mcp.actions.block_primitive"
                        }}
                        @icon={{if primitive.emergency_blocked "unlock" "ban"}}
                        @isLoading={{eq this.updatingPrimitiveId primitive.id}}
                        class="btn-transparent btn-small"
                      />
                    </div>
                  </article>
                {{else}}
                  <p class="admin-mcp__empty">{{i18n
                      "admin.config.mcp.primitives.no_results"
                    }}</p>
                {{/each}}
              </div>
            </section>
          </div>
          <form.Actions
            class={{if this.hasPrimitiveChanges "is-floating"}}
            {{dOnResize this.positionPrimitiveActions}}
          >
            <form.Submit @label="admin.config.mcp.save_primitives" />
          </form.Actions>
        </Form>
      </div>
    {{else if (eq @section "clients")}}
      <DPageSubheader
        @titleLabel={{i18n "admin.config.mcp.clients.title"}}
        @descriptionLabel={{i18n "admin.config.mcp.clients.description"}}
        @learnMoreUrl="https://meta.discourse.org/t/connecting-your-apps-to-discourse-mcp-server/411637#p-2033870-connecting-apps-via-oauth-2"
      >
        <:actions as |actions|>
          <actions.Primary
            @route="adminConfig.mcp.clients.new"
            @label="admin.config.mcp.clients.add"
          />
        </:actions>
      </DPageSubheader>
      {{#if this.hasClients}}
        <Form
          @data={{this.clientFilterFormData}}
          @onSet={{this.updateFilter}}
          class="admin-mcp__table-filter"
          as |form|
        >
          <form.Field
            @name="clientFilter"
            @title={{i18n "admin.config.mcp.clients.search_placeholder"}}
            @showTitle={{false}}
            @showOptional={{false}}
            @type="input"
            as |field|
          >
            <field.Control
              placeholder={{i18n "admin.config.mcp.clients.search_placeholder"}}
            />
          </form.Field>
        </Form>
        <DLoadMore
          @action={{this.loadMoreClients}}
          @enabled={{this.canLoadMoreClients}}
          @isLoading={{this.clientLoading}}
          @rootMargin="0px 0px 250px 0px"
          class="admin-mcp__load-more"
        >
          <table class="d-table admin-mcp__table">
            <thead class="d-table__header"><tr class="d-table__row"><th
                  class="d-table__cell --overview"
                >{{i18n "admin.config.mcp.clients.client"}}</th><th
                  class="d-table__cell --detail"
                >{{i18n "admin.config.mcp.clients.trust"}}</th><th
                  class="d-table__cell --detail"
                >{{i18n "admin.config.mcp.clients.last_seen"}}</th><th
                  class="d-table__cell --detail"
                >{{i18n "admin.config.mcp.clients.authorizations"}}</th><th
                  class="d-table__cell --controls"
                ><span class="sr-only">{{i18n
                      "admin.config.mcp.clients.actions"
                    }}</span></th></tr></thead>
            <tbody class="d-table__body">
              {{#each this.filteredClients as |client|}}
                <tr class="d-table__row">
                  <td class="d-table__cell --overview"><LinkTo
                      @route="adminConfig.mcp.clients.show"
                      @model={{client.id}}
                      class="d-table__overview-link"
                    ><span
                        class="d-table__overview-name"
                      >{{client.name}}</span><small
                      >{{client.client_id}}</small></LinkTo></td>
                  <td class="d-table__cell --detail"><div
                      class="d-table__mobile-label"
                    >{{i18n "admin.config.mcp.clients.trust"}}</div><span
                      class="admin-mcp__status"
                      data-state={{client.trust_state}}
                    >{{mcpValue "client_trust" client.trust_state}}</span></td>
                  <td class="d-table__cell --detail"><div
                      class="d-table__mobile-label"
                    >{{i18n "admin.config.mcp.clients.last_seen"}}</div>{{#if
                      client.last_seen_at
                    }}{{dAgeWithTooltip
                        client.last_seen_at
                        format="medium"
                      }}{{else}}{{i18n "admin.config.mcp.never"}}{{/if}}</td>
                  <td class="d-table__cell --detail"><div
                      class="d-table__mobile-label"
                    >{{i18n
                        "admin.config.mcp.clients.authorizations"
                      }}</div>{{client.authorization_count}}</td>
                  <td class="d-table__cell --controls"><div
                      class="d-table__mobile-label"
                    >{{i18n "admin.config.mcp.clients.actions"}}</div><div
                      class="d-table__cell-actions"
                    >{{#if (eq client.registration_type "cimd")}}<DButton
                          @action={{fn this.refreshClient client}}
                          @label="admin.config.mcp.actions.refresh_metadata"
                          class="btn-small btn-transparent --primary admin-mcp__refresh-client"
                        />{{/if}}<DButton
                        @action={{fn this.toggleClientBlock client}}
                        @label={{if
                          client.blocked
                          "admin.config.mcp.clients.unblock"
                          "admin.config.mcp.clients.block"
                        }}
                        class={{if
                          client.blocked
                          "btn-small btn-default admin-mcp__toggle-client-block"
                          "btn-small btn-danger admin-mcp__toggle-client-block"
                        }}
                      /></div></td>
                </tr>
              {{else}}
                <tr class="d-table__row"><td
                    class="d-table__cell"
                    colspan="5"
                  >{{i18n "admin.config.mcp.clients.no_results"}}</td></tr>
              {{/each}}
            </tbody>
          </table>
        </DLoadMore>
        <DConditionalLoadingSpinner @condition={{this.clientLoading}} />
      {{else}}
        <AdminConfigAreaEmptyList
          @emptyLabel="admin.config.mcp.clients.empty"
          @ctaLabel="admin.config.mcp.clients.add"
          @ctaRoute="adminConfig.mcp.clients.new"
        />
      {{/if}}
    {{else if (eq @section "client-new")}}
      {{#if this.selectedClientPresetId}}
        <DButton
          class="btn-transparent back-button admin-mcp__change-client-preset"
          @action={{this.resetClientPreset}}
          @icon="chevron-left"
          @label="admin.config.mcp.clients.back_to_presets"
        />
        <AdminConfigAreaCard
          class="admin-mcp__client-form"
          @heading="admin.config.mcp.clients.new_title"
        >
          <:content>
            <p>{{i18n
                (concat
                  "admin.config.mcp.clients.preset_help."
                  this.selectedClientPresetId
                )
              }}</p>
            <Form
              @data={{this.newClientFormData}}
              @isLoading={{this.saving}}
              @onSubmit={{this.createClient}}
              as |form|
            >
              <form.Field
                @description={{i18n
                  "admin.config.mcp.clients.name_description"
                }}
                @format="large"
                @name="name"
                @title={{i18n "admin.config.mcp.clients.name"}}
                @type="input"
                @validation="required"
                as |field|
              ><field.Control /></form.Field>
              <form.Field
                @description={{i18n
                  "admin.config.mcp.clients.client_id_description"
                }}
                @format="large"
                @name="client_id"
                @title={{i18n "admin.config.mcp.clients.client_id"}}
                @type="input"
                @validation="required"
                as |field|
              ><field.Control /></form.Field>
              <form.Field
                @description={{i18n
                  "admin.config.mcp.clients.redirect_uris_description"
                }}
                @format="large"
                @name="redirect_uris"
                @title={{i18n "admin.config.mcp.clients.redirect_uris"}}
                @type="textarea"
                @validation="required"
                as |field|
              ><field.Control @height={{100}} /></form.Field>
              <form.Submit @label="admin.config.mcp.clients.create" />
            </Form>
          </:content>
        </AdminConfigAreaCard>
      {{else}}
        <BackButton
          @label="admin.config.mcp.clients.back"
          @route="adminConfig.mcp.clients"
        />
        <section class="admin-mcp__client-presets">
          <h2>{{i18n "admin.config.mcp.clients.preset_title"}}</h2>
          <p>{{i18n "admin.config.mcp.clients.preset_description"}}</p>
          <AdminSectionLandingWrapper>
            {{#each this.clientPresetIds as |preset|}}
              <AdminSectionLandingItem
                data-client-preset-id={{preset}}
                @descriptionLabel={{concat
                  "admin.config.mcp.clients.preset_descriptions."
                  preset
                }}
                @titleLabel={{concat
                  "admin.config.mcp.clients.presets."
                  preset
                }}
              >
                <:buttons as |buttons|>
                  <buttons.Default
                    @action={{fn this.selectClientPreset preset}}
                    @icon="gear"
                    @label="admin.config.mcp.clients.use_preset"
                  />
                </:buttons>
              </AdminSectionLandingItem>
            {{/each}}
          </AdminSectionLandingWrapper>
        </section>
      {{/if}}
    {{else if (eq @section "client-detail")}}
      <BackButton
        @route="adminConfig.mcp.clients"
        @label="admin.config.mcp.clients.back"
      />
      <DPageSubheader
        @titleLabel={{this.client.name}}
        @descriptionLabel={{i18n "admin.config.mcp.clients.detail_description"}}
      >
        <:actions as |actions|>
          <actions.Default
            @action={{fn this.toggleClientBlock this.client}}
            @label={{if
              this.client.blocked
              "admin.config.mcp.actions.unblock_client"
              "admin.config.mcp.actions.block_client"
            }}
          />
          {{#if (eq this.client.registration_type "cimd")}}
            <actions.Default
              @action={{fn this.refreshClient this.client}}
              @label="admin.config.mcp.actions.refresh_metadata"
            />
          {{/if}}
        </:actions>
      </DPageSubheader>
      <AdminConfigAreaCard @heading="admin.config.mcp.clients.detail_title">
        <:content>
          <dl class="admin-mcp__detail-list">
            <div><dt>{{i18n "admin.config.mcp.clients.client_id"}}</dt><dd><code
                >{{this.client.client_id}}</code></dd></div>
            <div><dt>{{i18n "admin.config.mcp.clients.trust"}}</dt><dd><span
                  class="admin-mcp__status"
                  data-state={{this.client.trust_state}}
                >{{mcpValue
                    "client_trust"
                    this.client.trust_state
                  }}</span></dd></div>
            {{#if this.client.domain}}
              <div><dt>{{i18n "admin.config.mcp.clients.domain"}}</dt><dd
                >{{this.client.domain}}</dd></div>
            {{/if}}
            <div><dt>{{i18n
                  "admin.config.mcp.clients.registration_type"
                }}</dt><dd>{{mcpValue
                  "registration_type"
                  this.client.registration_type
                }}</dd></div>
            <div><dt>{{i18n "admin.config.mcp.clients.redirect_uris"}}</dt><dd>
                <ul class="admin-mcp__uri-list">
                  {{#each this.client.redirect_uris as |uri|}}
                    <li><code>{{uri}}</code></li>
                  {{/each}}
                </ul>
              </dd></div>
            <div><dt>{{i18n "admin.config.mcp.clients.first_seen"}}</dt><dd
              >{{dFormatDate this.client.first_seen_at}}</dd></div>
            <div><dt>{{i18n "admin.config.mcp.clients.last_seen"}}</dt><dd>{{#if
                  this.client.last_seen_at
                }}{{dFormatDate this.client.last_seen_at}}{{else}}{{i18n
                    "admin.config.mcp.never"
                  }}{{/if}}</dd></div>
          </dl>
        </:content>
      </AdminConfigAreaCard>
    {{else if (eq @section "authorizations")}}
      <DPageSubheader
        @titleLabel={{i18n "admin.config.mcp.authorizations.title"}}
        @descriptionLabel={{i18n "admin.config.mcp.authorizations.description"}}
      />
      <Form
        @data={{this.authorizationFilterFormData}}
        @onSet={{this.updateFilter}}
        class="admin-mcp__table-filter"
        as |form|
      >
        <form.Field
          @name="authorizationFilter"
          @title={{i18n "admin.config.mcp.authorizations.search_placeholder"}}
          @showTitle={{false}}
          @showOptional={{false}}
          @type="input"
          as |field|
        >
          <field.Control
            placeholder={{i18n
              "admin.config.mcp.authorizations.search_placeholder"
            }}
          />
        </form.Field>
      </Form>
      <DLoadMore
        @action={{this.loadMoreAuthorizations}}
        @enabled={{this.canLoadMoreAuthorizations}}
        @isLoading={{this.authorizationLoading}}
        @rootMargin="0px 0px 250px 0px"
        class="admin-mcp__load-more"
      >
        <table class="d-table admin-mcp__table admin-mcp__authorizations-table">
          <colgroup>
            <col class="admin-mcp__authorizations-client-column" />
            <col class="admin-mcp__authorizations-user-column" />
            <col class="admin-mcp__authorizations-scopes-column" />
            <col class="admin-mcp__authorizations-last-used-column" />
            <col class="admin-mcp__authorizations-status-column" />
            <col class="admin-mcp__authorizations-actions-column" />
          </colgroup>
          <thead class="d-table__header"><tr class="d-table__row"><th
                class="d-table__cell --overview"
              >{{i18n "admin.config.mcp.authorizations.client"}}</th><th
                class="d-table__cell --detail"
              >{{i18n "admin.config.mcp.authorizations.user"}}</th><th
                class="d-table__cell --detail"
              >{{i18n "admin.config.mcp.authorizations.scopes"}}</th><th
                class="d-table__cell --detail"
              >{{i18n "admin.config.mcp.authorizations.last_used"}}</th><th
                class="d-table__cell --detail"
              >{{i18n "admin.config.mcp.authorizations.status"}}</th><th
                class="d-table__cell --controls"
              ><span class="sr-only">{{i18n
                    "admin.config.mcp.authorizations.actions"
                  }}</span></th></tr></thead>
          <tbody class="d-table__body">
            {{#each this.filteredAuthorizations as |authorization|}}
              <tr class="d-table__row">
                <td class="d-table__cell --overview"><span
                    class="d-table__overview-name"
                  >{{authorization.client_name}}</span></td>
                <td class="d-table__cell --detail"><div
                    class="d-table__mobile-label"
                  >{{i18n
                      "admin.config.mcp.authorizations.user"
                    }}</div>{{authorization.username}}</td>
                <td class="d-table__cell --detail"><div
                    class="d-table__mobile-label"
                  >{{i18n "admin.config.mcp.authorizations.scopes"}}</div><code
                  >{{listValue authorization.scopes}}</code></td>
                <td class="d-table__cell --detail"><div
                    class="d-table__mobile-label"
                  >{{i18n
                      "admin.config.mcp.authorizations.last_used"
                    }}</div>{{#if authorization.last_used_at}}{{dAgeWithTooltip
                      authorization.last_used_at
                      format="medium"
                    }}{{else}}{{i18n "admin.config.mcp.never"}}{{/if}}</td>
                <td class="d-table__cell --detail"><div
                    class="d-table__mobile-label"
                  >{{i18n "admin.config.mcp.authorizations.status"}}</div><span
                    class="admin-mcp__status"
                    data-state={{authorization.status}}
                  >{{mcpValue
                      "authorization_status"
                      authorization.status
                    }}</span></td>
                <td class="d-table__cell --controls">{{#if
                    (notEq authorization.status "revoked")
                  }}<DButton
                      @action={{fn this.revokeAuthorization authorization}}
                      @label="admin.config.mcp.actions.revoke"
                      class="btn-small btn-danger"
                    />{{/if}}</td>
              </tr>
            {{else}}
              <tr class="d-table__row"><td
                  class="d-table__cell"
                  colspan="6"
                >{{i18n "admin.config.mcp.authorizations.empty"}}</td></tr>
            {{/each}}
          </tbody>
        </table>
      </DLoadMore>
      <DConditionalLoadingSpinner @condition={{this.authorizationLoading}} />
    {{else if (eq @section "activity")}}
      <DPageSubheader
        @titleLabel={{i18n "admin.config.mcp.activity.title"}}
        @descriptionLabel={{i18n "admin.config.mcp.activity.description"}}
      />
      <div class="admin-mcp__metric-grid admin-mcp__activity-metrics">
        <div><dt>{{i18n "admin.config.mcp.activity.tool_calls"}}</dt><dd
          >{{this.metrics.tool_calls}}</dd></div><div><dt>{{i18n
              "admin.config.mcp.activity.errors"
            }}</dt><dd>{{this.metrics.errors}}</dd></div><div><dt>{{i18n
              "admin.config.mcp.activity.rate_limits"
            }}</dt><dd>{{this.metrics.rate_limits}}</dd></div><div><dt>{{i18n
              "admin.config.mcp.activity.p95_latency"
            }}</dt><dd>{{i18n
              "admin.config.mcp.activity.duration_value"
              milliseconds=this.metrics.p95_latency_ms
            }}</dd></div>
      </div>
      <Form
        @data={{this.activityFilterFormData}}
        @onSet={{this.updateFilter}}
        class="admin-mcp__activity-filters"
        as |form|
      >
        <form.Field
          @name="activityFilter"
          @title={{i18n "admin.config.mcp.activity.search_placeholder"}}
          @showTitle={{false}}
          @showOptional={{false}}
          @format="full"
          @type="input"
          class="admin-mcp__filter-search"
          as |field|
        >
          <field.Control
            placeholder={{i18n "admin.config.mcp.activity.search_placeholder"}}
          />
        </form.Field>
        <form.Field
          @name="activityOutcome"
          @title={{i18n "admin.config.mcp.activity.outcome"}}
          @showTitle={{false}}
          @showOptional={{false}}
          @type="select"
          as |field|
        >
          <field.Control
            @includeNone={{false}}
            aria-label={{i18n "admin.config.mcp.activity.outcome"}}
            as |select|
          >
            {{#each this.activityOutcomes as |outcome|}}
              <select.Option @value={{outcome}}>
                {{mcpValue "activity_outcome" outcome}}
              </select.Option>
            {{/each}}
          </field.Control>
        </form.Field>
      </Form>
      <DLoadMore
        @action={{this.loadMoreActivity}}
        @enabled={{this.canLoadMoreActivity}}
        @isLoading={{this.activityLoading}}
        @rootMargin="0px 0px 250px 0px"
        class="admin-mcp__load-more"
      >
        <table class="d-table admin-mcp__table admin-mcp__activity-table">
          <thead class="d-table__header"><tr class="d-table__row"><th
                class="d-table__cell --detail"
              >{{i18n "admin.config.mcp.activity.time"}}</th><th
                class="d-table__cell --overview"
              >{{i18n "admin.config.mcp.activity.method"}}</th><th
                class="d-table__cell --detail"
              >{{i18n "admin.config.mcp.activity.user"}}</th><th
                class="d-table__cell --detail"
              >{{i18n "admin.config.mcp.activity.outcome"}}</th><th
                class="d-table__cell --detail"
              >{{i18n "admin.config.mcp.activity.duration"}}</th><th
                class="d-table__cell --detail"
              >{{i18n "admin.config.mcp.activity.request_id"}}</th></tr></thead>
          <tbody class="d-table__body">{{#each this.activity as |event|}}<tr
                class="d-table__row"
              ><td class="d-table__cell --detail"><div
                    class="d-table__mobile-label"
                  >{{i18n "admin.config.mcp.activity.time"}}</div>{{dFormatDate
                    event.created_at
                  }}</td><td class="d-table__cell --overview"><span
                    class="d-table__overview-name"
                  >{{event.tool}}</span><small>{{event.method}}</small></td><td
                  class="d-table__cell --detail"
                ><div class="d-table__mobile-label">{{i18n
                      "admin.config.mcp.activity.user"
                    }}</div>{{event.username}}</td><td
                  class="d-table__cell --detail"
                ><div class="d-table__mobile-label">{{i18n
                      "admin.config.mcp.activity.outcome"
                    }}</div><span
                    class="admin-mcp__status"
                    data-state={{event.outcome}}
                  >{{mcpValue "activity_outcome" event.outcome}}</span></td><td
                  class="d-table__cell --detail"
                ><div class="d-table__mobile-label">{{i18n
                      "admin.config.mcp.activity.duration"
                    }}</div>{{event.duration_ms}}
                  ms</td><td class="d-table__cell --detail"><div
                    class="d-table__mobile-label"
                  >{{i18n "admin.config.mcp.activity.request_id"}}</div><code
                  >{{event.request_id}}</code></td></tr>{{else}}<tr
                class="d-table__row"
              ><td class="d-table__cell" colspan="6">{{i18n
                    "admin.config.mcp.activity.empty"
                  }}</td></tr>{{/each}}</tbody>
        </table>
      </DLoadMore>
      <DConditionalLoadingSpinner @condition={{this.activityLoading}} />
    {{/if}}
  </template>
}
