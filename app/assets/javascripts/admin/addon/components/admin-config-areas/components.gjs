import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DropdownMenu from "discourse/components/dropdown-menu";
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
import AdminFilterControls from "admin/components/admin-filter-controls";
import InstallComponentModal from "admin/components/modal/install-theme";
import { COMPONENTS } from "admin/models/theme";
import DMenu from "float-kit/components/d-menu";

const STATUS_FILTER_OPTIONS = [
  {
    value: "all",
    label: i18n(
      "admin.config_areas.themes_and_components.components.filter_by_all"
    ),
  },
  {
    value: "used",
    label: i18n(
      "admin.config_areas.themes_and_components.components.filter_by_used"
    ),
  },
  {
    value: "unused",
    label: i18n(
      "admin.config_areas.themes_and_components.components.filter_by_unused"
    ),
  },
  {
    value: "updates_available",
    label: i18n(
      "admin.config_areas.themes_and_components.components.filter_by_updates_available"
    ),
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

    this.router.transitionTo(
      "adminCustomizeThemes.show.index",
      "components",
      component.id
    );
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
  onResetFilters() {
    this.loading = true;
    this.nameFilter = null;
    this.statusFilter = null;
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
        <AdminFilterControls
          @array={{this.components}}
          @dropdownOptions={{STATUS_FILTER_OPTIONS}}
          @inputPlaceholder={{i18n
            "admin.config_areas.themes_and_components.components.search_components"
          }}
          @noResultsMessage={{i18n
            "admin.config_areas.themes_and_components.components.no_components_found"
          }}
          @onTextFilterChange={{this.onNameFilterChange}}
          @onDropdownFilterChange={{this.onStatusFilterChange}}
          @onResetFilters={{this.onResetFilters}}
          @loading={{this.loading}}
        >
          <:content>
            <LoadMore @action={{this.loadMore}} @rootMargin="0px 0px 250px 0px">
              <PluginOutlet
                @name="admin-config-area-components-above-table"
                @outletArgs={{lazyHash components=this.components}}
              />
              <table class="d-table component-list">
                <thead class="d-table__header">
                  <tr class="d-table__row">
                    <th class="d-table__header-cell">{{i18n
                        "admin.config_areas.themes_and_components.components.name"
                      }}</th>
                    <th class="d-table__header-cell">{{i18n
                        "admin.config_areas.themes_and_components.components.used_on"
                      }}</th>
                    <th class="d-table__header-cell">{{i18n
                        "admin.config_areas.themes_and_components.components.enabled"
                      }}</th>
                    <th class="d-table__header-cell"></th>
                  </tr>
                </thead>
                <tbody class="d-table__body">
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
          </:content>
        </AdminFilterControls>
      {{/if}}
      <ConditionalLoadingSpinner @condition={{this.loading}}>
        {{#unless this.hasComponents}}
          <AdminConfigAreaEmptyList
            @emptyLabel="admin.config_areas.themes_and_components.components.no_components"
          >
            <PluginOutlet
              @name="admin-config-area-components-empty-list-bottom"
            />
          </AdminConfigAreaEmptyList>
        {{/unless}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}

class ComponentRow extends Component {
  @service toasts;
  @service dialog;
  @service router;

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

  get editUrl() {
    return this.router.urlFor(
      "adminCustomizeThemes.show",
      "themes",
      this.args.component.id
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
      class="d-table__row admin-config-components__component-row
        {{if this.hasUpdates 'has-update'}}"
    >
      <td class="d-table__cell --overview">
        <a class="d-table__overview-name" href={{this.editUrl}}>
          {{@component.name}}
        </a>
        {{#if @component.remote_theme.authors}}
          <div
            class="d-table__overview-author admin-config-components__author-name"
          >{{i18n
              "admin.config_areas.themes_and_components.components.by_author"
              (hash name=@component.remote_theme.authors)
            }}</div>
        {{/if}}
        {{#if this.description}}
          <div
            class="d-table__overview-about admin-config-components__description"
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
            class="d-table__overview-about admin-config-components__update-available"
          >
            {{i18n
              "admin.config_areas.themes_and_components.components.update_available"
            }}
          </div>
        {{/if}}
      </td>
      <td class="d-table__cell --detail admin-config-components__parent-themes">
        <div class="d-table__mobile-label">
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
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">
          {{i18n "admin.config_areas.themes_and_components.components.enabled"}}
        </div>
        <DToggleSwitch
          @state={{this.enabled}}
          class="admin-config-components__toggle"
          disabled={{this.disableToggle}}
          {{on "click" this.toggleEnabled}}
        />
      </td>
      <td class="d-table__cell --controls">
        <div class="d-table__cell-actions">
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
