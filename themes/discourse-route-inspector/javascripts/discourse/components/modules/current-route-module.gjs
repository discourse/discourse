import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import { computeLong } from "../../lib/compute-long";
import { filterData } from "../../lib/filter-data";
import { getDefaultCollapsed } from "../../lib/inspector-section-config";
import InspectorDataTable from "../inspector-data-table";
import InspectorSection from "../inspector-section";

const ALLOWED_PARAMS = [
  "id",
  "slug",
  "nearPost",
  "username",
  "tag_id",
  "category_id",
  "category_slug_path_with_id",
];
const ALLOWED_QUERY_PARAMS = ["page", "sort", "order", "filter", "asc", "q"];
const ALLOWED_ATTRIBUTES = [
  "id",
  "filterType",
  "filter",
  "loaded",
  "track_visit",
  "forceLoad",
  "can_create_topic",
  "canCreateTopic",
  "per_page",
  "canCreateTopicOnCategory",
  "canCreateTopicOnTag",
  "user_count",
  "request_count",
  "username",
  "name",
  "title",
  "locale",
  "unicodeTitle",
  "version",
  "noSubcategories",
  "stream",
];

export default class CurrentRouteModule extends Component {
  @service router;
  @service routeInspectorState;

  get sectionKey() {
    return "current-route";
  }

  get defaultCollapsed() {
    return getDefaultCollapsed(this.sectionKey);
  }

  get routeName() {
    return this.router.currentRouteName;
  }

  get routeData() {
    const route = this.router.currentRoute;
    if (!route) {
      return {};
    }

    const data = {};

    // Add name first
    data.name = this.routeName;

    // Add parent if available
    if (route.parent?.name) {
      data.parent = route.parent.name;
    }

    // Merge params
    const params = this.applyFilters(route.params, ALLOWED_PARAMS);
    if (Object.keys(params).length > 0) {
      data.params = {
        _type: "param",
        _data: params,
      };
    }

    // Merge queryParams
    const queryParams = this.applyFilters(
      route.queryParams,
      ALLOWED_QUERY_PARAMS
    );
    if (Object.keys(queryParams).length > 0) {
      data.queryParams = {
        _type: "param",
        _data: queryParams,
      };
    }

    // Merge attributes
    if (route.attributes) {
      const attrs = this.applyFilters(route.attributes, ALLOWED_ATTRIBUTES);
      if (Object.keys(attrs).length > 0) {
        data.attributes = {
          _type: "param",
          _data: attrs,
        };
      }
    }

    return data;
  }

  get filteredData() {
    return filterData(
      this.routeData,
      this.routeInspectorState.filter,
      this.routeInspectorState.filterCaseSensitive
    );
  }

  get isLong() {
    return computeLong(this.filteredData);
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
    <InspectorSection
      @label={{i18n (themePrefix "route_inspector.route_module.title")}}
      @icon="lucide-map-pin"
      @long={{this.isLong}}
      @sectionKey={{this.sectionKey}}
      @defaultCollapsed={{this.defaultCollapsed}}
      @isCollapsed={{@isCollapsed}}
      @onToggle={{@onToggle}}
    >
      <InspectorDataTable
        @data={{this.filteredData}}
        @tableKey="current-route"
        @onDrillInto={{@onDrillInto}}
      />
    </InspectorSection>
  </template>
}
