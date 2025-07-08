import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DSelect from "discourse/components/d-select";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DropdownMenu from "discourse/components/dropdown-menu";
import FilterInput from "discourse/components/filter-input";
import LoadMore from "discourse/components/load-more";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { extractErrorInfo } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import { descriptionForRemoteUrl } from "discourse/lib/popular-themes";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import InstallComponentModal from "admin/components/modal/install-theme";
import { COMPONENTS } from "admin/models/theme";
import DMenu from "float-kit/components/d-menu";

const STATUS_FILTER_OPTIONS = [
  {
    value: "all",
    label: "admin.config_areas.themes_and_components.components.filter_by_all",
  },
  {
    value: "used",
    label: "admin.config_areas.themes_and_components.components.filter_by_used",
  },
  {
    value: "unused",
    label:
      "admin.config_areas.themes_and_components.components.filter_by_unused",
  },
  {
    value: "updates_available",
    label:
      "admin.config_areas.themes_and_components.components.filter_by_updates_available",
  },
];

export default class AdminConfigAreasComponents extends Component {
  @service modal;
  @service router;
  @service toasts;

  @tracked loading = true;
  @tracked components = [];
  @tracked nameFilter;
  @tracked statusFilter;
  @tracked hasComponents = false;
  @tracked loadingMore = false;

  page = 0;
  hasMore = false;

  constructor() {
    super(...arguments);
    this.load();
  }

  @action
  installModal() {
    this.modal.show(InstallComponentModal, {
      model: { ...this.installOptions() },
    });
  }

  // TODO (martin) These install methods may not belong here and they
  // are incomplete or have stubbed or omitted properties. We may want
  // to move this to the new config route or a dedicated component
  // that sits in the route.
  installOptions() {
    return {
      selectedType: COMPONENTS,
      userId: null,
      content: [],
      installedThemes: this.components,
      addTheme: this.addComponent,
      updateSelectedType: () => {},
      showComponentsOnly: true,
    };
  }

  @action
  addComponent(component) {
    this.toasts.success({
      data: {
        message: i18n("admin.customize.theme.install_success", {
          theme: component.name,
        }),
      },
      duration: "short",
    });
    this.load();
  }

  @action
  onNameFilterChange(event) {
    this.loading = true;
    this.nameFilter = event.target.value;
    this.page = 0;
    discourseDebounce(this, this.load, INPUT_DELAY);
  }

  @action
  onStatusFilterChange(value) {
    this.loading = true;
    this.statusFilter = value;
    this.page = 0;
    this.load();
  }

  @action
  async load({ append = false } = {}) {
    try {
      const data = await ajax("/admin/config/customize/components", {
        data: {
          name: this.nameFilter,
          status: this.statusFilter,
          page: this.page,
        },
      });

      if (append) {
        this.components = [...this.components, ...data.components];
      } else {
        this.components = data.components;
      }
      this.hasMore = data.has_more;

      if (!this.hasComponents && !this.nameFilter && !this.statusFilter) {
        this.hasComponents = !!data.components.length;
      }
    } finally {
      this.loading = false;
    }
  }

  @action
  async loadMore() {
    if (this.loadingMore) {
      return;
    }

    if (this.hasMore) {
      this.page += 1;
      this.loadingMore = true;
      try {
        await this.load({ append: true });
      } finally {
        this.loadingMore = false;
      }
    }
  }

  @action
  deleteComponentById(id) {
    this.components = this.components.filter((c) => c.id !== id);

    if (
      this.components.length === 0 &&
      !this.nameFilter &&
      !this.statusFilter
    ) {
      this.hasComponents = false;
    }
  }

  <template>
    <DPageSubheader
      @titleLabel={{i18n
        "admin.config_areas.themes_and_components.components.title"
      }}
      @descriptionLabel={{i18n
        "admin.config_areas.themes_and_components.components.description"
      }}
    >
      <:actions as |actions|>
        <PluginOutlet
          @name="admin-config-area-components-new-button"
          @outletArgs={{lazyHash actions=actions}}
        >
          <actions.Primary
            @label="admin.config_areas.themes_and_components.components.install"
            @action={{this.installModal}}
          />
        </PluginOutlet>
      </:actions>
    </DPageSubheader>
    <div class="container">
      {{#if this.hasComponents}}
        <div class="d-admin-filter">
          <div
            class="admin-filter__input-container admin-config-components__name-filter"
          >
            <FilterInput
              placeholder={{i18n
                "admin.config_areas.themes_and_components.components.search_components"
              }}
              @filterAction={{this.onNameFilterChange}}
              class="admin-filter__input"
            />
          </div>

          <label class="admin-config-components__status-filter">
            {{i18n
              "admin.config_areas.themes_and_components.components.filter_by"
            }}
            <DSelect
              @value="all"
              @includeNone={{false}}
              @onChange={{this.onStatusFilterChange}}
              as |select|
            >
              {{#each STATUS_FILTER_OPTIONS as |option|}}
                <select.Option @value={{option.value}}>
                  {{i18n option.label}}
                </select.Option>
              {{/each}}
            </DSelect>
          </label>
        </div>
      {{/if}}
      <ConditionalLoadingSpinner @condition={{this.loading}}>
        {{#if this.components.length}}
          <LoadMore @action={{this.loadMore}}>
            <table class="d-admin-table component-list">
              <thead>
                <th>{{i18n
                    "admin.config_areas.themes_and_components.components.name"
                  }}</th>
                <th>{{i18n
                    "admin.config_areas.themes_and_components.components.used_on"
                  }}</th>
                <th>{{i18n
                    "admin.config_areas.themes_and_components.components.enabled"
                  }}</th>
                <th></th>
              </thead>
              <tbody>
                {{#each this.components as |comp|}}
                  <ComponentRow
                    @component={{comp}}
                    @deleteComponent={{this.deleteComponentById}}
                  />
                {{/each}}
              </tbody>
            </table>
            <ConditionalLoadingSpinner @condition={{this.loadingMore}} />
          </LoadMore>
        {{else}}
          {{#if this.hasComponents}}
            {{i18n
              "admin.config_areas.themes_and_components.components.no_components_found"
            }}
          {{else}}
            <AdminConfigAreaEmptyList
              @emptyLabel="admin.config_areas.themes_and_components.components.no_components"
            >
              <PluginOutlet
                @name="admin-config-area-components-empty-list-bottom"
              />
            </AdminConfigAreaEmptyList>
          {{/if}}
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}

class ComponentRow extends Component {
  @service toasts;
  @service dialog;

  @tracked enabled = this.args.component.enabled;
  @tracked hasUpdates = this.args.component.remote_theme?.commits_behind > 0;
  @tracked disableToggle = false;
  @tracked checkingForUpdates = false;
  @tracked updating = false;

  get parentThemesCell() {
    const names = this.args.component.parent_themes.map((theme) => theme.name);
    names.sort();

    if (!names.length) {
      return;
    } else if (names.length === 1) {
      return names[0];
    } else if (names.length === 2) {
      return i18n(
        "admin.config_areas.themes_and_components.components.parent_themes_two",
        {
          name1: names[0],
          name2: names[1],
        }
      );
    } else if (names.length === 3) {
      return i18n(
        "admin.config_areas.themes_and_components.components.parent_themes_three",
        {
          name1: names[0],
          name2: names[1],
          name3: names[2],
        }
      );
    } else {
      return i18n(
        "admin.config_areas.themes_and_components.components.parent_themes_more_than_three",
        {
          name1: names[0],
          name2: names[1],
          name3: names[2],
          count: names.length - 3,
        }
      );
    }
  }

  get description() {
    const remoteUrl = this.args.component.remote_theme?.remote_url;
    return (
      this.args.component.description ??
      (remoteUrl && descriptionForRemoteUrl(remoteUrl))
    );
  }

  @action
  async toggleEnabled() {
    this.disableToggle = true;
    try {
      const data = await this.save({ enabled: !this.enabled });
      this.enabled = data.theme.enabled;
    } finally {
      this.disableToggle = false;
    }
  }

  @action
  async checkForUpdates() {
    this.checkingForUpdates = true;

    try {
      const data = await this.save({ remote_check: true });
      if (data.theme.remote_theme.commits_behind > 0) {
        this.hasUpdates = true;
        this.toasts.default({
          duration: "long",
          data: {
            message: i18n(
              "admin.config_areas.themes_and_components.components.new_update_for_component",
              { name: this.args.component.name }
            ),
          },
        });
      } else {
        this.hasUpdates = false;
        this.toasts.default({
          duration: "long",
          data: {
            message: i18n(
              "admin.config_areas.themes_and_components.components.component_up_to_date",
              { name: this.args.component.name }
            ),
          },
        });
      }
    } finally {
      this.checkingForUpdates = false;
    }
  }

  @action
  async updateToLatest() {
    this.updating = true;

    try {
      await this.save({ remote_update: true });
      this.hasUpdates = false;
      this.toasts.success({
        duration: "long",
        data: {
          message: i18n(
            "admin.config_areas.themes_and_components.components.updated_successfully",
            { name: this.args.component.name }
          ),
        },
      });
    } finally {
      this.updating = false;
    }
  }

  @action
  delete() {
    return this.dialog.deleteConfirm({
      title: i18n(
        "admin.config_areas.themes_and_components.components.delete_confirm",
        { name: this.args.component.name }
      ),
      didConfirm: async () => {
        try {
          await ajax(`/admin/themes/${this.args.component.id}`, {
            type: "DELETE",
          });
          this.toasts.success({
            duration: "long",
            data: {
              message: i18n(
                "admin.config_areas.themes_and_components.components.deleted_successfully",
                { name: this.args.component.name }
              ),
            },
          });
          this.args.deleteComponent(this.args.component.id);
        } catch (error) {
          this.toasts.error({
            duration: "long",
            data: {
              message: extractErrorInfo(error),
            },
          });
        }
      },
    });
  }

  async save(attrs) {
    try {
      return await ajax(`/admin/themes/${this.args.component.id}.json`, {
        type: "PUT",
        data: {
          theme: attrs,
        },
      });
    } catch (error) {
      this.toasts.error({
        duration: "long",
        data: {
          message: extractErrorInfo(error),
        },
      });
      throw error;
    }
  }

  <template>
    <tr
      data-component-id={{@component.id}}
      class="d-admin-row__content admin-config-components__component-row
        {{if this.hasUpdates 'has-update'}}"
    >
      <td class="d-admin-row__overview">
        <div class="d-admin-row__overview-name">
          {{@component.name}}
        </div>
        {{#if @component.remote_theme.authors}}
          <div
            class="d-admin-row__overview-author admin-config-components__author-name"
          >{{i18n
              "admin.config_areas.themes_and_components.components.by_author"
              (hash name=@component.remote_theme.authors)
            }}</div>
        {{/if}}
        {{#if this.description}}
          <div
            class="d-admin-row__overview-about admin-config-components__description"
          >
            {{this.description}}
            {{#if @component.remote_theme.about_url}}
              <a href={{@component.remote_theme.about_url}}>{{i18n
                  "admin.config_areas.themes_and_components.components.learn_more"
                }}
                {{icon "up-right-from-square"}}
              </a>
            {{/if}}
          </div>
        {{/if}}
        {{#if this.hasUpdates}}
          <div
            class="d-admin-row__overview-about admin-config-components__update-available"
          >
            {{i18n
              "admin.config_areas.themes_and_components.components.update_available"
            }}
          </div>
        {{/if}}
      </td>
      <td class="d-admin-row__detail admin-config-components__parent-themes">
        <div class="d-admin-row__mobile-label">
          {{i18n "admin.config_areas.themes_and_components.components.used_on"}}
        </div>
        <div class="admin-config-components__parent-themes-list">
          {{#if @component.parent_themes.length}}
            {{this.parentThemesCell}}
          {{else}}
            <div class="status-label --inactive">
              <div class="status-label-indicator"></div>
              <div class="status-label-text">
                {{i18n
                  "admin.config_areas.themes_and_components.components.badge_unused"
                }}
              </div>
            </div>
          {{/if}}
        </div>
      </td>
      <td class="d-admin-row__detail">
        <div class="d-admin-row__mobile-label">
          {{i18n "admin.config_areas.themes_and_components.components.enabled"}}
        </div>
        <DToggleSwitch
          @state={{this.enabled}}
          class="admin-config-components__toggle"
          disabled={{this.disableToggle}}
          {{on "click" this.toggleEnabled}}
        />
      </td>
      <td class="d-admin-row__controls">
        <div class="d-admin-row__controls-options">
          <DButton
            class="admin-config-components__edit"
            @label="admin.config_areas.themes_and_components.components.edit"
            @route="adminCustomizeThemes.show"
            @routeModels={{array "themes" @component.id}}
          />
          <DMenu
            @identifier="component-menu"
            @title={{i18n "admin.config_areas.flags.more_options.title"}}
            @icon="ellipsis"
            @class="btn-default admin-config-components__more-actions"
          >
            <:content>
              <DropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    class="btn-transparent admin-config-components__preview"
                    target="_blank"
                    rel="noopener noreferrer"
                    @label="admin.config_areas.themes_and_components.components.preview"
                    @icon="desktop"
                    @href={{getURL
                      (concat "/admin/themes/" @component.id "/preview")
                    }}
                  />
                </dropdown.item>
                {{#if @component.remote_theme.is_git}}
                  <dropdown.item>
                    {{#if this.hasUpdates}}
                      <DButton
                        class="btn-transparent admin-config-components__update"
                        @label="admin.config_areas.themes_and_components.components.update"
                        @icon="cloud-arrow-down"
                        @action={{this.updateToLatest}}
                        @isLoading={{this.updating}}
                      />
                    {{else}}
                      <DButton
                        class="btn-transparent admin-config-components__check-updates"
                        @label="admin.config_areas.themes_and_components.components.check_update"
                        @icon="arrows-rotate"
                        @action={{this.checkForUpdates}}
                        @isLoading={{this.checkingForUpdates}}
                      />
                    {{/if}}
                  </dropdown.item>
                {{/if}}
                <dropdown.item>
                  <DButton
                    class="btn-transparent admin-config-components__export"
                    target="_blank"
                    rel="noopener noreferrer"
                    @label="admin.config_areas.themes_and_components.components.export"
                    @icon="download"
                    @href={{getURL
                      (concat
                        "/admin/customize/themes/" @component.id "/export"
                      )
                    }}
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    class="btn-danger admin-config-components__delete"
                    @label="admin.config_areas.themes_and_components.components.delete"
                    @icon="trash-can"
                    @action={{this.delete}}
                  />
                </dropdown.item>
              </DropdownMenu>
            </:content>
          </DMenu>
        </div>
      </td>
    </tr>
  </template>
}
