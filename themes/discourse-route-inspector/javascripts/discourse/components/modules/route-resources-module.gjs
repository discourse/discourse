import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DataSection from "../data-section";

const FINGERPRINTS = {
  category: ["uploaded_logo", "default_list_filter"],
  topicList: ["per_page", "topics"],
  user: ["username", "avatar_template"],
  topic: ["fancy_title", "posts_count"],
  tag: ["topic_count", "name"],
};

function matchesFingerprint(obj, fingerprint) {
  if (!obj || typeof obj !== "object") {
    return false;
  }
  return fingerprint.every((key) => key in obj);
}

function identifyDataType(obj) {
  for (const [type, fingerprint] of Object.entries(FINGERPRINTS)) {
    if (matchesFingerprint(obj, fingerprint)) {
      return type;
    }
  }
  return null;
}

export default class RouteResourcesModule extends Component {
  @service router;
  @service currentUser;

  get isCurrentUserModuleEnabled() {
    if (!this.args.enabledModules) {
      return false;
    }
    return this.args.enabledModules.some((mod) => mod.id === "current-user");
  }

  get tables() {
    const route = this.router.currentRoute;
    if (!route) {
      return [];
    }

    const resourceTables = this.findResourceTables(route);
    const tables = [];

    const resourceTableConfigs = {
      category: { label: i18n("category_title"), icon: "lucide-folder" },
      tag: { label: i18n("tagging.tag"), icon: "lucide-tag" },
      topicList: {
        label: i18n(themePrefix("route_inspector.topic_list_label")),
        icon: "lucide-list",
      },
      topic: { label: i18n("topic.title"), icon: "lucide-file-text" },
      user: {
        label: i18n(themePrefix("route_inspector.user_label")),
        icon: "lucide-user",
      },
    };

    for (const [key, config] of Object.entries(resourceTableConfigs)) {
      if (resourceTables[key]) {
        // Skip user resource if current user module is enabled and user matches current user
        if (
          key === "user" &&
          this.isCurrentUserModuleEnabled &&
          this.currentUser &&
          resourceTables[key].data.username === this.currentUser.username
        ) {
          continue;
        }

        tables.push({
          key,
          label: config.label,
          icon: config.icon,
          data: resourceTables[key].data,
          source: resourceTables[key].source,
        });
      }
    }

    return tables;
  }

  get hasContent() {
    return this.tables.length > 0;
  }

  findResourceTables(route) {
    const sources = [
      { path: "attributes", data: route.attributes },
      { path: "parent.attributes", data: route.parent?.attributes },
      {
        path: "parent.parent.attributes",
        data: route.parent?.parent?.attributes,
      },
      { path: "model", data: route.model },
    ];

    if (route.attributes?.category) {
      sources.push({
        path: "attributes.category",
        data: route.attributes.category,
      });
    }
    if (route.attributes?.topic_list) {
      sources.push({
        path: "attributes.topic_list",
        data: route.attributes.topic_list,
      });
    }
    if (route.attributes?.list?.topic_list) {
      sources.push({
        path: "attributes.list.topic_list",
        data: route.attributes.list.topic_list,
      });
    }

    const resourceTables = {};

    for (const source of sources) {
      if (!source.data || typeof source.data !== "object") {
        continue;
      }

      const dataType = identifyDataType(source.data);

      if (dataType && !resourceTables[dataType]) {
        const tableData = {};
        for (const [key, value] of Object.entries(source.data)) {
          if (value !== null && value !== undefined && !key.startsWith("_")) {
            tableData[key] = value;
          }
        }

        if (Object.keys(tableData).length > 0) {
          resourceTables[dataType] = {
            data: tableData,
            source: source.path,
          };
        }
      }
    }

    return resourceTables;
  }

  <template>
    {{#if this.hasContent}}
      {{#each this.tables as |table|}}
        <DataSection
          @sectionKey={{concat "route-resources." table.key}}
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
