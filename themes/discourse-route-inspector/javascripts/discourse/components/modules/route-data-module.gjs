import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DataSection from "../data-section";

const ALLOWED_MODEL_KEYS = [
  "can_edit",
  "can_delete",
  "username",
  "name",
  "title",
  "id",
];

export default class RouteDataModule extends Component {
  @service router;

  get tables() {
    const route = this.router.currentRoute;
    if (!route) {
      return [];
    }

    const tables = [];

    if (route.model && typeof route.model === "object") {
      const model = this.applyFilters(route.model, ALLOWED_MODEL_KEYS);
      if (Object.keys(model).length > 0) {
        tables.push({
          key: "modelAttributes",
          label: i18n(themePrefix("route_inspector.model_label")),
          icon: "circle-info",
          data: model,
        });
      }
    }

    return tables;
  }

  get hasContent() {
    return this.tables.length > 0;
  }

  applyFilters(obj, allowList) {
    if (!obj) {
      return {};
    }
    const result = {};
    for (const [key, value] of Object.entries(obj)) {
      if (
        value !== null &&
        value !== undefined &&
        !key.startsWith("_") &&
        allowList.includes(key)
      ) {
        result[key] = value;
      }
    }
    return result;
  }

  <template>
    {{#if this.hasContent}}
      {{#each this.tables as |table|}}
        <DataSection
          @sectionKey={{concat "route-data." table.key}}
          @label={{table.label}}
          @icon={{table.icon}}
          @rawData={{table.data}}
          @tableKey={{table.key}}
          @isSectionCollapsed={{@isSectionCollapsed}}
          @onToggleSection={{@onToggleSection}}
          @onDrillInto={{@onDrillInto}}
        />
      {{/each}}
    {{/if}}
  </template>
}
