import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { eq, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DMultiSelect from "discourse/ui-kit/d-multi-select";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

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
  @service dialog;
  @service router;
  @service site;
  @service toasts;

  @tracked capabilityFilter = "";
  @tracked capabilityProvider = "all";
  @tracked capabilityKind = "all";
  @tracked capabilityScope = "all";
  @tracked capabilityRisk = "all";
  @tracked capabilityState = "all";
  @tracked authorizationFilter = "";
  @tracked clientFilter = "";
  @tracked activityFilter = "";
  @tracked activityOutcome = "all";
  @tracked capabilityFormApi;
  @tracked saving = false;
  @tracked clients;
  @tracked clientRecord;
  @tracked capabilityRecords;
  @tracked updatingCapabilityId;
  @tracked authorizations;
  @tracked activity;
  @tracked activityNextCursor;

  capabilityFilterFormData = {
    capabilityFilter: "",
    capabilityProvider: "all",
    capabilityKind: "all",
    capabilityScope: "all",
    capabilityRisk: "all",
    capabilityState: "all",
  };
  clientFilterFormData = { clientFilter: "" };
  authorizationFilterFormData = { authorizationFilter: "" };
  activityFilterFormData = { activityFilter: "", activityOutcome: "all" };

  constructor() {
    super(...arguments);
    const model = this.args.model || {};
    this.clients = model.clients || model.oauth_clients;
    this.clientRecord = model.client;
    this.capabilityRecords = model.capabilities;
    this.authorizations = model.authorizations;
    this.activity = model.activity || model.events;
    this.activityNextCursor = model.meta?.next_cursor;
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

  get adminGroupId() {
    return this.groupOptions
      ?.find((group) => group.name === "admins")
      ?.id.toString();
  }

  get configuration() {
    return (
      this.model.configuration || this.model.config || this.model.profile || {}
    );
  }

  get capabilities() {
    return this.capabilityRecords || this.model.capabilities || [];
  }

  get catalog() {
    return this.model.catalog || {};
  }

  get metrics() {
    return this.model.metrics || {};
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

  get filteredCapabilities() {
    const filter = this.capabilityFilter.trim().toLowerCase();

    return this.capabilities.filter((capability) => {
      const matchesText =
        !filter ||
        [
          capability.id,
          capability.name,
          capability.title,
          capability.description,
          capability.provider,
          ...(capability.required_scopes || []),
        ]
          .filter(Boolean)
          .join(" ")
          .toLowerCase()
          .includes(filter);
      const matchesProvider =
        this.capabilityProvider === "all" ||
        capability.provider === this.capabilityProvider;
      const matchesKind =
        this.capabilityKind === "all" ||
        capability.kind === this.capabilityKind;
      const matchesScope =
        this.capabilityScope === "all" ||
        capability.required_scopes?.includes(this.capabilityScope);
      const matchesRisk =
        this.capabilityRisk === "all" ||
        capability.risk === this.capabilityRisk;
      const matchesState =
        this.capabilityState === "all" ||
        (this.capabilityState === "enabled" && capability.enabled) ||
        (this.capabilityState === "disabled" && !capability.enabled) ||
        (this.capabilityState === "unavailable" && !capability.available) ||
        (this.capabilityState === "blocked" && capability.emergency_blocked);

      return (
        matchesText &&
        matchesProvider &&
        matchesKind &&
        matchesScope &&
        matchesRisk &&
        matchesState
      );
    });
  }

  get capabilityProviders() {
    return [
      "all",
      ...new Set(
        this.capabilities
          .map((capability) => capability.provider)
          .filter(Boolean)
      ),
    ];
  }

  get capabilityKinds() {
    return [
      "all",
      ...new Set(
        this.capabilities.map((capability) => capability.kind).filter(Boolean)
      ),
    ];
  }

  get capabilityScopes() {
    return ["all", ...this.scopeOptions.map((scope) => scope.id)];
  }

  get capabilityRisks() {
    return [
      "all",
      ...new Set(
        this.capabilities.map((capability) => capability.risk).filter(Boolean)
      ),
    ];
  }

  get capabilityStates() {
    return ["all", "enabled", "disabled", "unavailable", "blocked"];
  }

  get scopeOptions() {
    const counts = new Map();
    this.capabilities.forEach((capability) => {
      (capability.required_scopes || []).forEach((scope) => {
        counts.set(scope, (counts.get(scope) || 0) + 1);
      });
    });

    const scopes = this.model.available_scopes || [...counts.keys()];
    return scopes.map((scope) => ({
      id: scope,
      name: scope,
      capabilityCount: counts.get(scope) || 0,
    }));
  }

  get selectedScopeOptions() {
    const options = new Map(
      this.scopeOptions.map((option) => [option.id, option])
    );
    return (this.configuration.allowed_scopes || []).map(
      (scope) =>
        options.get(scope) || {
          id: scope,
          name: scope,
          capabilityCount: 0,
        }
    );
  }

  get configurationFormData() {
    return {
      server_enabled: Boolean(
        this.configuration.server_enabled ?? this.configuration.enabled
      ),
      instructions: this.configuration.instructions || "",
      allowed_group_ids: (
        this.configuration.allowed_group_ids ||
        this.configuration.allowed_groups ||
        []
      ).map(String),
      allowed_scopes: this.selectedScopeOptions,
      cache_ttl_ms: this.configuration.cache_ttl_ms || 0,
    };
  }

  get newClientFormData() {
    return { name: "", client_id: "", redirect_uris: "" };
  }

  get capabilityFormData() {
    return this.capabilities.reduce((data, capability) => {
      data[this.capabilityFieldName(capability)] = Boolean(capability.enabled);
      return data;
    }, {});
  }

  get clientRecords() {
    return this.clients || this.model.clients || this.model.oauth_clients || [];
  }

  get hasClients() {
    return this.clientRecords.length > 0;
  }

  get filteredClients() {
    const filter = this.clientFilter.trim().toLowerCase();
    return this.clientRecords.filter((client) => {
      if (!filter) {
        return true;
      }
      return [
        client.name,
        client.client_id,
        client.domain,
        client.registration_type,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase()
        .includes(filter);
    });
  }

  get filteredAuthorizations() {
    const filter = this.authorizationFilter.trim().toLowerCase();
    const authorizations =
      this.authorizations || this.model.authorizations || [];
    return authorizations.filter((authorization) => {
      if (!filter) {
        return true;
      }
      return [
        authorization.client_name,
        authorization.client_id,
        authorization.username,
        authorization.profile,
        authorization.status,
        ...(authorization.scopes || []),
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase()
        .includes(filter);
    });
  }

  get filteredActivity() {
    const filter = this.activityFilter.trim().toLowerCase();
    const activity =
      this.activity || this.model.activity || this.model.events || [];
    return activity.filter((event) => {
      const matchesText =
        !filter ||
        [
          event.method,
          event.tool,
          event.client_name,
          event.username,
          event.outcome,
        ]
          .filter(Boolean)
          .join(" ")
          .toLowerCase()
          .includes(filter);
      const matchesOutcome =
        this.activityOutcome === "all" ||
        event.outcome === this.activityOutcome;
      return matchesText && matchesOutcome;
    });
  }

  get activityOutcomes() {
    return [
      "all",
      ...new Set(
        (this.activity || this.model.activity || [])
          .map((event) => event.outcome)
          .filter(Boolean)
      ),
    ];
  }

  capabilityFieldName(capability) {
    return capability.field_name;
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
      case "capabilityFilter":
        this.capabilityFilter = value;
        break;
      case "capabilityProvider":
        this.capabilityProvider = value;
        break;
      case "capabilityKind":
        this.capabilityKind = value;
        break;
      case "capabilityScope":
        this.capabilityScope = value;
        break;
      case "capabilityRisk":
        this.capabilityRisk = value;
        break;
      case "capabilityState":
        this.capabilityState = value;
        break;
      case "clientFilter":
        this.clientFilter = value;
        break;
      case "authorizationFilter":
        this.authorizationFilter = value;
        break;
      case "activityFilter":
        this.activityFilter = value;
        break;
      case "activityOutcome":
        this.activityOutcome = value;
        break;
    }
  }

  @action
  registerCapabilityForm(api) {
    this.capabilityFormApi = api;
  }

  @action
  selectVisibleCapabilities(enabled) {
    this.filteredCapabilities.forEach((capability) => {
      this.capabilityFormApi?.set(
        this.capabilityFieldName(capability),
        enabled
      );
    });
  }

  @action
  saveConfiguration(data) {
    const save = () => this.#saveConfiguration(data);
    if (
      data.server_enabled &&
      !(this.configuration.server_enabled ?? this.configuration.enabled)
    ) {
      this.dialog.confirm({
        message: i18n("admin.config.mcp.confirm_enable"),
        didConfirm: save,
      });
      return;
    }
    return save();
  }

  async #saveConfiguration(data) {
    this.saving = true;
    try {
      await ajax("/admin/mcp/configuration.json", {
        type: "PUT",
        data: {
          configuration: {
            enabled: data.server_enabled,
            instructions: data.instructions,
            cache_ttl_ms: data.cache_ttl_ms,
            allowed_group_ids: (data.allowed_group_ids || []).map(Number),
            allowed_scopes: (data.allowed_scopes || []).map(
              (scope) => scope.id
            ),
          },
        },
      });
      this.toasts.success({
        duration: "short",
        data: { message: i18n("admin.config.mcp.saved") },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  async saveCapabilities(data) {
    this.saving = true;
    try {
      const enabledCapabilities = Object.entries(data)
        .filter(([, enabled]) => enabled)
        .map(
          ([field]) =>
            this.capabilities.find(
              (capability) => capability.field_name === field
            )?.id
        )
        .filter(Boolean);
      await ajax("/admin/mcp/capabilities.json", {
        type: "PUT",
        data: { capability_ids: enabledCapabilities },
      });
      this.toasts.success({
        duration: "short",
        data: { message: i18n("admin.config.mcp.capabilities_saved") },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  async #setCapabilityBlocked(capability, blocked) {
    this.updatingCapabilityId = capability.id;
    try {
      await ajax("/admin/mcp/capabilities/emergency-block.json", {
        type: "PUT",
        data: { capability_id: capability.id, blocked },
      });
      this.capabilityRecords = this.capabilityRecords.map((item) =>
        item.id === capability.id
          ? { ...item, emergency_blocked: blocked }
          : item
      );
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            blocked
              ? "admin.config.mcp.capability_blocked"
              : "admin.config.mcp.capability_unblocked",
            { name: capability.title || capability.name }
          ),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.updatingCapabilityId = null;
    }
  }

  @action
  toggleCapabilityEmergencyBlock(capability) {
    const blocked = !capability.emergency_blocked;
    const updateBlock = () => this.#setCapabilityBlocked(capability, blocked);

    if (blocked) {
      this.dialog.confirm({
        message: i18n("admin.config.mcp.confirm_emergency_block", {
          name: capability.title || capability.name,
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
  async loadMoreActivity() {
    if (!this.activityNextCursor) {
      return;
    }
    try {
      const result = await ajax("/admin/mcp/activity.json", {
        data: { cursor: this.activityNextCursor },
      });
      this.activity = [
        ...this.activity,
        ...(result.activity || result.events || []),
      ];
      this.activityNextCursor = result.meta?.next_cursor;
    } catch (error) {
      popupAjaxError(error);
    }
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
          @description="admin.config.mcp.overview.endpoint_description"
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
              <div><dt>{{i18n "admin.config.mcp.overview.server_state"}}</dt><dd
                >{{i18n
                    (if
                      @model.enabled
                      "admin.config.mcp.overview.enabled"
                      "admin.config.mcp.overview.disabled"
                    )
                  }}</dd></div>
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
        >
          <:content>
            <dl class="admin-mcp__metric-grid">
              <div><dt>{{i18n
                    "admin.config.mcp.overview.active_clients"
                  }}</dt><dd>{{this.metrics.active_clients}}</dd></div>
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
    {{else if (eq @section "capabilities")}}
      <DPageSubheader
        @titleLabel={{i18n "admin.config.mcp.capabilities.title"}}
        @descriptionLabel={{i18n "admin.config.mcp.capabilities.description"}}
      />
      <AdminConfigAreaCard
        @heading="admin.config.mcp.access.title"
        @description="admin.config.mcp.access.description"
      >
        <:content>
          <Form
            @data={{this.configurationFormData}}
            @onSubmit={{this.saveConfiguration}}
            @isLoading={{this.saving}}
            class="admin-mcp__configuration-form"
            as |form|
          >
            <form.Field
              @name="server_enabled"
              @title={{i18n "admin.config.mcp.access.enabled"}}
              @type="checkbox"
              as |field|
            ><field.Control /></form.Field>
            <form.Field
              @name="instructions"
              @title={{i18n "admin.config.mcp.access.instructions"}}
              @type="textarea"
              as |field|
            ><field.Control @height={{80}} /></form.Field>
            <form.Field
              @name="allowed_group_ids"
              @title={{i18n "admin.config.mcp.access.allowed_groups"}}
              @description={{i18n
                "admin.config.mcp.access.allowed_groups_description"
              }}
              @type="custom"
              as |field|
            >
              <field.Control>
                <GroupChooser
                  @content={{this.groupOptions}}
                  @value={{field.value}}
                  @onChange={{field.set}}
                  @mandatoryValues={{this.adminGroupId}}
                  @mandatoryValueTitle={{i18n
                    "admin.config.mcp.access.administrators_always_included"
                  }}
                />
              </field.Control>
            </form.Field>
            <form.Field
              @name="allowed_scopes"
              @title={{i18n "admin.config.mcp.access.allowed_scopes"}}
              @description={{i18n
                "admin.config.mcp.access.allowed_scopes_description"
              }}
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
                  @label={{i18n
                    "admin.config.mcp.access.allowed_scopes_placeholder"
                  }}
                  @contentClass="admin-mcp__scope-select-content"
                  class="admin-mcp__scope-select"
                >
                  <:selection as |scope|>{{scope.name}}</:selection>
                  <:result as |scope|>
                    <span class="admin-mcp__scope-option">
                      <span>{{scope.name}}</span>
                      <small>{{i18n
                          "admin.config.mcp.access.scope_capabilities"
                          count=scope.capabilityCount
                        }}</small>
                    </span>
                  </:result>
                </DMultiSelect>
              </field.Control>
            </form.Field>
            <form.Field
              @name="cache_ttl_ms"
              @title={{i18n "admin.config.mcp.access.cache_ttl"}}
              @validation="required|integer"
              @type="input-number"
              as |field|
            ><field.Control
                min="1000"
                max="86400000"
                step="1000"
              /></form.Field>
            <form.Submit @label="admin.config.mcp.save_configuration" />
          </Form>
        </:content>
      </AdminConfigAreaCard>

      <DPageSubheader
        @titleLabel={{i18n "admin.config.mcp.capabilities.picker_title"}}
        @descriptionLabel={{i18n
          "admin.config.mcp.capabilities.picker_description"
        }}
      />
      <Form
        @data={{this.capabilityFilterFormData}}
        @onSet={{this.updateFilter}}
        class="admin-mcp__capability-filters"
        as |form|
      >
        <form.Field
          @name="capabilityFilter"
          @title={{i18n "admin.config.mcp.capabilities.search_placeholder"}}
          @showTitle={{false}}
          @showOptional={{false}}
          @type="input"
          class="admin-mcp__filter-search"
          as |field|
        >
          <field.Control
            placeholder={{i18n
              "admin.config.mcp.capabilities.search_placeholder"
            }}
          />
        </form.Field>
        <form.Field
          @name="capabilityProvider"
          @title={{i18n "admin.config.mcp.capabilities.provider"}}
          @showTitle={{false}}
          @showOptional={{false}}
          @type="select"
          as |field|
        >
          <field.Control
            @includeNone={{false}}
            aria-label={{i18n "admin.config.mcp.capabilities.provider"}}
            as |select|
          >
            {{#each this.capabilityProviders as |provider|}}
              <select.Option @value={{provider}}>{{#if
                  (eq provider "all")
                }}{{mcpValue
                    "filter"
                    "all"
                  }}{{else}}{{provider}}{{/if}}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>
        <form.Field
          @name="capabilityKind"
          @title={{i18n "admin.config.mcp.capabilities.kind"}}
          @showTitle={{false}}
          @showOptional={{false}}
          @type="select"
          as |field|
        >
          <field.Control
            @includeNone={{false}}
            aria-label={{i18n "admin.config.mcp.capabilities.kind"}}
            as |select|
          >
            {{#each this.capabilityKinds as |kind|}}
              <select.Option @value={{kind}}>{{mcpValue
                  "capability_kind"
                  kind
                }}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>
        <form.Field
          @name="capabilityScope"
          @title={{i18n "admin.config.mcp.capabilities.scope"}}
          @showTitle={{false}}
          @showOptional={{false}}
          @type="select"
          class="admin-mcp__filter-scope"
          as |field|
        >
          <field.Control
            @includeNone={{false}}
            aria-label={{i18n "admin.config.mcp.capabilities.scope"}}
            as |select|
          >
            {{#each this.capabilityScopes as |scope|}}
              <select.Option @value={{scope}}>{{#if (eq scope "all")}}{{i18n
                    "admin.config.mcp.capabilities.any_scope"
                  }}{{else}}{{scope}}{{/if}}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>
        <form.Field
          @name="capabilityRisk"
          @title={{i18n "admin.config.mcp.capabilities.risk"}}
          @showTitle={{false}}
          @showOptional={{false}}
          @type="select"
          class="admin-mcp__filter-impact"
          as |field|
        >
          <field.Control
            @includeNone={{false}}
            aria-label={{i18n "admin.config.mcp.capabilities.risk"}}
            as |select|
          >
            {{#each this.capabilityRisks as |risk|}}
              <select.Option @value={{risk}}>{{mcpValue
                  "capability_risk"
                  risk
                }}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>
        <form.Field
          @name="capabilityState"
          @title={{i18n "admin.config.mcp.capabilities.state"}}
          @showTitle={{false}}
          @showOptional={{false}}
          @type="select"
          as |field|
        >
          <field.Control
            @includeNone={{false}}
            aria-label={{i18n "admin.config.mcp.capabilities.state"}}
            as |select|
          >
            {{#each this.capabilityStates as |state|}}
              <select.Option @value={{state}}>{{mcpValue
                  "capability_state"
                  state
                }}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>
      </Form>
      <p class="admin-mcp__results-count" aria-live="polite">{{i18n
          "admin.config.mcp.capabilities.results_count"
          visible=this.filteredCapabilities.length
          total=this.capabilities.length
        }}</p>
      <Form
        @data={{this.capabilityFormData}}
        @onRegisterApi={{this.registerCapabilityForm}}
        @onSubmit={{this.saveCapabilities}}
        @isLoading={{this.saving}}
        as |form|
      >
        <div class="admin-mcp__bulk-actions">
          <DButton
            @action={{fn this.selectVisibleCapabilities true}}
            @label="admin.config.mcp.capabilities.enable_visible"
            class="btn-default btn-small"
          />
          <DButton
            @action={{fn this.selectVisibleCapabilities false}}
            @label="admin.config.mcp.capabilities.disable_visible"
            class="btn-default btn-small"
          />
        </div>
        <div class="admin-mcp__capability-list">
          {{#each this.filteredCapabilities as |capability|}}
            <article
              class="admin-mcp__capability"
              data-capability-id={{capability.id}}
            >
              <form.Field
                @name={{capability.field_name}}
                @title={{capability.title}}
                @showTitle={{false}}
                @type="checkbox"
                as |field|
              >
                <field.Control
                  disabled={{or
                    (not capability.available)
                    capability.emergency_blocked
                  }}
                >{{capability.description}}</field.Control>
              </form.Field>
              <dl class="admin-mcp__capability-meta">
                <div><dt>{{i18n
                      "admin.config.mcp.capabilities.provider"
                    }}</dt><dd>{{capability.provider}}</dd></div>
                <div><dt>{{i18n "admin.config.mcp.capabilities.kind"}}</dt><dd
                  >{{mcpValue "capability_kind" capability.kind}}</dd></div>
                <div><dt>{{i18n "admin.config.mcp.capabilities.risk"}}</dt><dd
                  >{{mcpValue "capability_risk" capability.risk}}</dd></div>
                <div><dt>{{i18n "admin.config.mcp.capabilities.scopes"}}</dt><dd
                  >{{listValue capability.required_scopes}}</dd></div>
              </dl>
              {{#unless capability.available}}<p
                  class="admin-mcp__unavailable"
                >{{capability.unavailable_reason}}</p>{{/unless}}
              {{#if capability.emergency_blocked}}<p
                  class="admin-mcp__unavailable"
                >{{i18n
                    "admin.config.mcp.capabilities.emergency_blocked"
                  }}</p>{{/if}}
              <div class="admin-mcp__capability-actions">
                <DButton
                  @action={{fn this.toggleCapabilityEmergencyBlock capability}}
                  @title={{if
                    capability.emergency_blocked
                    "admin.config.mcp.actions.unblock_capability"
                    "admin.config.mcp.actions.block_capability"
                  }}
                  @icon={{if capability.emergency_blocked "unlock" "ban"}}
                  @isLoading={{eq this.updatingCapabilityId capability.id}}
                  class="btn-transparent btn-small"
                />
              </div>
            </article>
          {{else}}
            <p class="admin-mcp__empty">{{i18n
                "admin.config.mcp.capabilities.no_results"
              }}</p>
          {{/each}}
        </div>
        <form.Submit @label="admin.config.mcp.save_capabilities" />
      </Form>
    {{else if (eq @section "clients")}}
      <DPageSubheader
        @titleLabel={{i18n "admin.config.mcp.clients.title"}}
        @descriptionLabel={{i18n "admin.config.mcp.clients.description"}}
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
                    class="d-table__cell-actions"
                  ><DButton
                      @action={{fn this.toggleClientBlock client}}
                      @label={{if
                        client.blocked
                        "admin.config.mcp.actions.unblock_client"
                        "admin.config.mcp.actions.block_client"
                      }}
                      class="btn-small btn-default"
                    />{{#if (eq client.registration_type "cimd")}}<DButton
                        @action={{fn this.refreshClient client}}
                        @label="admin.config.mcp.actions.refresh_metadata"
                        class="btn-small btn-transparent"
                      />{{/if}}</div></td>
              </tr>
            {{else}}
              <tr class="d-table__row"><td
                  class="d-table__cell"
                  colspan="5"
                >{{i18n "admin.config.mcp.clients.no_results"}}</td></tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <AdminConfigAreaEmptyList
          @emptyLabel="admin.config.mcp.clients.empty"
          @ctaLabel="admin.config.mcp.clients.add"
          @ctaRoute="adminConfig.mcp.clients.new"
        />
      {{/if}}
    {{else if (eq @section "client-new")}}
      <BackButton
        @route="adminConfig.mcp.clients"
        @label="admin.config.mcp.clients.back"
      />
      <AdminConfigAreaCard
        @heading="admin.config.mcp.clients.new_title"
        class="admin-mcp__form-card"
      >
        <:content>
          <Form
            @data={{this.newClientFormData}}
            @onSubmit={{this.createClient}}
            @isLoading={{this.saving}}
            as |form|
          >
            <form.Field
              @name="name"
              @title={{i18n "admin.config.mcp.clients.name"}}
              @validation="required"
              @type="input"
              as |field|
            ><field.Control /></form.Field>
            <form.Field
              @name="client_id"
              @title={{i18n "admin.config.mcp.clients.client_id"}}
              @description={{i18n
                "admin.config.mcp.clients.client_id_description"
              }}
              @validation="required"
              @type="input"
              as |field|
            ><field.Control /></form.Field>
            <form.Field
              @name="redirect_uris"
              @title={{i18n "admin.config.mcp.clients.redirect_uris"}}
              @description={{i18n
                "admin.config.mcp.clients.redirect_uris_description"
              }}
              @validation="required"
              @type="textarea"
              as |field|
            ><field.Control @height={{100}} /></form.Field>
            <form.Submit @label="admin.config.mcp.clients.create" />
          </Form>
        </:content>
      </AdminConfigAreaCard>
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
      <table class="d-table admin-mcp__table">
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
                >{{authorization.client_name}}</span><small
                >{{authorization.profile}}</small></td>
              <td class="d-table__cell --detail"><div
                  class="d-table__mobile-label"
                >{{i18n
                    "admin.config.mcp.authorizations.user"
                  }}</div>{{authorization.username}}</td>
              <td class="d-table__cell --detail"><div
                  class="d-table__mobile-label"
                >{{i18n "admin.config.mcp.authorizations.scopes"}}</div><span
                >{{listValue authorization.scopes}}</span></td>
              <td class="d-table__cell --detail"><div
                  class="d-table__mobile-label"
                >{{i18n "admin.config.mcp.authorizations.last_used"}}</div>{{#if
                  authorization.last_used_at
                }}{{dAgeWithTooltip
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
                  (eq authorization.status "active")
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
    {{else if (eq @section "activity")}}
      <DPageSubheader
        @titleLabel={{i18n "admin.config.mcp.activity.title"}}
        @descriptionLabel={{i18n "admin.config.mcp.activity.description"}}
      />
      <div class="admin-mcp__metric-grid admin-mcp__activity-metrics">
        <div><dt>{{i18n "admin.config.mcp.activity.calls"}}</dt><dd
          >{{this.metrics.calls}}</dd></div><div><dt>{{i18n
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
              <select.Option @value={{outcome}}>{{#if
                  (eq outcome "all")
                }}{{mcpValue "filter" "all"}}{{else}}{{mcpValue
                    "activity_outcome"
                    outcome
                  }}{{/if}}</select.Option>
            {{/each}}
          </field.Control>
        </form.Field>
      </Form>
      <table class="d-table admin-mcp__table">
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
        <tbody class="d-table__body">{{#each
            this.filteredActivity
            as |event|
          }}<tr class="d-table__row"><td class="d-table__cell --detail"><div
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
      {{#if this.activityNextCursor}}<DButton
          @action={{this.loadMoreActivity}}
          @label="admin.config.mcp.activity.load_more"
          class="btn-default"
        />{{/if}}
    {{/if}}
  </template>
}
