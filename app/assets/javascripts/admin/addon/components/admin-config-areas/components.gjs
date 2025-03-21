import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DSelect from "discourse/components/d-select";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DropdownMenu from "discourse/components/dropdown-menu";
import FilterInput from "discourse/components/filter-input";
import { ajax } from "discourse/lib/ajax";
import { extractErrorInfo } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import InstallComponentModal from "admin/components/modal/install-theme";
import { COMPONENTS } from "admin/models/theme";
import DMenu from "float-kit/components/d-menu";

const STATUS_FILTER_OPTIONS = [
  {
    value: "all",
    label: "admin.config_areas.themes_and_components.components.filter_by_all",
  },
  {
    value: "active",
    label:
      "admin.config_areas.themes_and_components.components.filter_by_active",
  },
  {
    value: "inactive",
    label:
      "admin.config_areas.themes_and_components.components.filter_by_inactive",
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
      installedThemes: this.args.components,
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
      duration: 2000,
    });
    this.router.refresh();
  }

  @action
  onNameFilterChange(event) {
    this.nameFilter = event.target.value;
    discourseDebounce(this, this.load, INPUT_DELAY);
  }

  @action
  onStatusFilterChange(value) {
    this.statusFilter = value;
    this.load();
  }

  async load() {
    this.loading = true;

    try {
      const data = await ajax("/admin/config/customize/components", {
        data: { name: this.nameFilter, status: this.statusFilter },
      });

      this.components = data.components;
    } finally {
      this.loading = false;
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
    />
    <div class="container">
      <div class="admin-config-components__filters">
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
        <div class="admin-config-components__name-filter">
          <FilterInput
            placeholder={{i18n
              "admin.config_areas.themes_and_components.components.search_components"
            }}
            @icons={{hash left="magnifying-glass"}}
            @filterAction={{this.onNameFilterChange}}
          />
        </div>
      </div>
      <ConditionalLoadingSpinner @condition={{this.loading}}>
        {{#if this.components.length}}
          <table class="d-admin-table">
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
            </thead>
            <tbody>
              {{#each this.components as |comp|}}
                <ComponentRow @component={{comp}} />
              {{/each}}
            </tbody>
          </table>
        {{else}}
          No components.
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}

class ComponentRow extends Component {
  @service toasts;

  @tracked enabled = this.args.component.enabled;
  @tracked hasUpdates = this.args.component.remote_theme?.commits_behind > 0;
  @tracked disableToggle = false;

  get parentThemesCell() {
    const themes = this.args.component.parent_themes;

    if (!themes.length) {
      return;
    } else if (themes.length === 1) {
      return themes[0].name;
    } else if (themes.length === 2) {
      return i18n(
        "admin.config_areas.themes_and_components.components.parent_themes_two",
        {
          name1: themes[0].name,
          name2: themes[1].name,
        }
      );
    } else if (themes.length === 3) {
      return i18n(
        "admin.config_areas.themes_and_components.components.parent_themes_three",
        {
          name1: themes[0].name,
          name2: themes[1].name,
          name3: themes[2].name,
        }
      );
    } else {
      return i18n(
        "admin.config_areas.themes_and_components.components.parent_themes_more_than_three",
        {
          name1: themes[0].name,
          name2: themes[1].name,
          name3: themes[2].name,
          count: themes.length - 3,
        }
      );
    }
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
  checkForUpdates() {}

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
        duration: 5000,
        data: {
          message: extractErrorInfo(error),
        },
      });
      throw error;
    }
  }

  <template>
    <tr class="d-admin-row__content">
      <td class="d-admin-row__overview">
        <div class="d-admin-row__overview-name">{{@component.name}}</div>
        {{#if @component.remote_theme.authors}}
          <div class="d-admin-row__overview-about">{{i18n
              "admin.config_areas.themes_and_components.components.by_author"
              (hash name=@component.remote_theme.authors)
            }}</div>
        {{/if}}
        {{#if @component.description}}
          <p>
            {{@component.description}}
            {{#if @component.remote_theme.about_url}}
              <a href={{@component.remote_theme.about_url}}>{{i18n
                  "admin.config_areas.themes_and_components.components.learn_more"
                }}</a>
            {{/if}}
          </p>
        {{/if}}
        {{#if this.hasUpdates}}
          <span>
            <b>{{i18n
                "admin.config_areas.themes_and_components.components.update_available"
              }}</b>
          </span>
        {{/if}}
      </td>
      <td class="d-admin-row__detail">
        {{#if @component.parent_themes.length}}
          {{this.parentThemesCell}}
        {{else}}
          <LinkTo
            @route="adminCustomizeThemes.show"
            @models={{array "themes" @component.id}}
          >
            {{i18n
              "admin.config_areas.themes_and_components.components.add_to_theme"
            }}
          </LinkTo>
        {{/if}}
      </td>
      <td class="d-admin-row__controls">
        <div class="d-admin-row__controls-options">
          <div class="d-admin-row__mobile-label">
            {{i18n
              "admin.config_areas.themes_and_components.components.enabled"
            }}
          </div>
          <DToggleSwitch
            @state={{this.enabled}}
            class="admin-component-item__toggle"
            disabled={{this.disableToggle}}
            {{on "click" this.toggleEnabled}}
          />
          <DButton
            @label="admin.config_areas.themes_and_components.components.edit"
            @route="adminCustomizeThemes.show"
            @routeModels={{array "themes" @component.id}}
          />
          <DMenu
            @identifier="component-menu"
            @title={{i18n "admin.config_areas.flags.more_options.title"}}
            @icon="ellipsis"
            @class="btn-default"
          >
            <:content>
              <DropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @label="admin.config_areas.themes_and_components.components.preview"
                    @icon="desktop"
                    @href={{getURL
                      (concat "/admin/themes/" @component.id "/preview")
                    }}
                    target="_blank"
                    class="btn-transparent admin-component-item__preview"
                  />
                </dropdown.item>
                {{#if @component.remote_theme.is_git}}
                  <dropdown.item>
                    {{#if this.hasUpdates}}
                      <DButton
                        @label="admin.config_areas.themes_and_components.components.update"
                        @icon="cloud-arrow-down"
                        class="btn-transparent admin-component-item__update"
                      />
                    {{else}}
                      <DButton
                        @label="admin.config_areas.themes_and_components.components.check_update"
                        @icon="arrows-rotate"
                        class="btn-transparent admin-component-item__check-updates"
                      />
                    {{/if}}
                  </dropdown.item>
                {{/if}}
                <dropdown.item>
                  <DButton
                    @label="admin.config_areas.themes_and_components.components.export"
                    @icon="download"
                    class="btn-transparent admin-component-item__export"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @label="admin.config_areas.themes_and_components.components.convert"
                    @icon="cube"
                    class="btn-transparent admin-component-item__convert"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @label="admin.config_areas.themes_and_components.components.delete"
                    @icon="trash-can"
                    class="btn-danger admin-component-item__delete"
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
