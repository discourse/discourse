import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import FilterField from "./filter-field";
import InspectorDataTable from "./inspector-data-table";
import CurrentRouteModule from "./modules/current-route-module";
import CurrentUserModule from "./modules/current-user-module";
import DeviceModule from "./modules/device-module";
import RouteDataModule from "./modules/route-data-module";
import RouteResourcesModule from "./modules/route-resources-module";
import RouteTreeModule from "./modules/route-tree-module";
import ViewportModule from "./modules/viewport-module";

const MODULES = [
  {
    id: "current-route",
    settingName: "route_inspector_show_current_route",
    component: CurrentRouteModule,
  },
  {
    id: "route-tree",
    settingName: "route_inspector_show_route_tree",
    component: RouteTreeModule,
  },
  {
    id: "route-data",
    settingName: "route_inspector_show_route_data",
    component: RouteDataModule,
  },
  {
    id: "route-resources",
    settingName: "route_inspector_show_route_data",
    component: RouteResourcesModule,
  },
  {
    id: "current-user",
    settingName: "route_inspector_show_current_user",
    component: CurrentUserModule,
  },
  {
    id: "viewport",
    settingName: "route_inspector_show_capabilities",
    component: ViewportModule,
  },
  {
    id: "device",
    settingName: "route_inspector_show_capabilities",
    component: DeviceModule,
  },
];

export default class RouteInspector extends Component {
  @service routeInspectorState;

  get isVisible() {
    return this.routeInspectorState.isVisible;
  }

  get isDetailsView() {
    return this.routeInspectorState.detailsHistory.length > 0;
  }

  get currentDetails() {
    if (!this.isDetailsView) {
      return null;
    }
    const history = this.routeInspectorState.detailsHistory;
    return history[history.length - 1];
  }

  get isSingleValueDetails() {
    if (!this.currentDetails) {
      return false;
    }
    const value = this.currentDetails.value;
    return !Array.isArray(value) && typeof value !== "object";
  }

  get enabledModules() {
    return MODULES.filter((m) => this.isModuleEnabled(m.settingName));
  }

  isModuleEnabled(settingName) {
    return settings[settingName] !== false;
  }

  <template>
    {{#if this.isVisible}}
      {{bodyClass "route-inspector-panel"}}
      <div
        class="route-inspector"
        role="region"
        aria-label={{i18n (themePrefix "route_inspector.aria_label")}}
      >
        <div class="route-inspector__layout">
          <div class="route-inspector__header">
            <div class="route-inspector__title">
              {{i18n (themePrefix "route_inspector.title")}}
            </div>

            <div class="route-inspector__controls">
              <button
                type="button"
                class="route-inspector__control route-inspector__close btn btn-transparent"
                {{on "click" this.routeInspectorState.toggleVisibility}}
                title={{i18n "close"}}
              >
                {{icon "lucide-x"}}
              </button>
            </div>
          </div>

          <div class="route-inspector__toolbar">
            <FilterField />
          </div>
          <div class="route-inspector__content">
            {{#if this.isDetailsView}}
              <div class="route-inspector__details-view">
                <div class="route-inspector__details-header">
                  <button
                    type="button"
                    class="route-inspector__back-btn"
                    {{on "click" this.routeInspectorState.goBackFromDetails}}
                  >
                    {{icon "lucide-move-left"}}
                  </button>
                  <h3
                    class="route-inspector__details-title"
                  >{{this.currentDetails.key}}</h3>
                </div>
                <div class="route-inspector__details-content">
                  <div class="route-inspector__section-content">
                    {{#if this.isSingleValueDetails}}
                      <InspectorDataTable
                        @data={{hash value=this.currentDetails.value}}
                        @tableKey="details-simple"
                        @onDrillInto={{this.routeInspectorState.drillIntoDetails}}
                        @isDetailView={{true}}
                        @isSimpleDetailsView={{true}}
                      />
                    {{else}}
                      <InspectorDataTable
                        @data={{this.currentDetails.value}}
                        @tableKey="details"
                        @onDrillInto={{this.routeInspectorState.drillIntoDetails}}
                        @isDetailView={{true}}
                        @isSimpleDetailsView={{false}}
                      />
                    {{/if}}
                  </div>
                </div>
              </div>
            {{else}}
              <div class="route-inspector__section-controls">
                <DButton
                  @action={{this.routeInspectorState.collapseAllSections}}
                  @icon="lucide-chevrons-down-up"
                  @disabled={{this.routeInspectorState.allSectionsCollapsed}}
                  @label={{themePrefix "route_inspector.collapse_all"}}
                  @class="route-inspector__section-control --collapse-all btn-default"
                />
                <DButton
                  @action={{this.routeInspectorState.expandAllSections}}
                  @icon="lucide-chevrons-up-down"
                  @disabled={{this.routeInspectorState.allSectionsExpanded}}
                  @label={{themePrefix "route_inspector.expand_all"}}
                  @class="route-inspector__section-control --expand-all btn-default"
                />
                <DButton
                  @label={{themePrefix "route_inspector.customize"}}
                  @icon="lucide-settings"
                  @class="route-inspector__section-control --customize customize-btn btn-default"
                />
              </div>
              <div class="route-inspector__modules-container">
                {{#each this.enabledModules as |mod|}}
                  <mod.component
                    @isCollapsed={{this.routeInspectorState.isSectionCollapsed
                      mod.id
                    }}
                    @onToggle={{fn
                      this.routeInspectorState.toggleSection
                      mod.id
                    }}
                    @isSectionCollapsed={{this.routeInspectorState.isSectionCollapsed}}
                    @onToggleSection={{this.routeInspectorState.toggleSection}}
                    @onDrillInto={{this.routeInspectorState.drillIntoDetails}}
                    @enabledModules={{this.enabledModules}}
                  />
                {{/each}}
                <div class="route-inspector__flex-spacer"></div>
              </div>
            {{/if}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
