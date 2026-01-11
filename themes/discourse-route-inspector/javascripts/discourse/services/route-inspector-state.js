import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";

export default class RouteInspectorState extends Service {
  @service keyValueStore;
  @service router;

  @tracked isVisible = false;
  @tracked detailsHistory = [];
  @tracked collapsedSections = new Map();
  @tracked filteredCollapseOverrides = new Map();
  @tracked expandedRouteNodes = new Map();
  @tracked showAllRouteNodes = new Set();
  @tracked filter = "";
  @tracked filterCaseSensitive = false;

  constructor() {
    super(...arguments);
    this.isVisible =
      this.keyValueStore.getItem("route-inspector-visible") === "true";

    this.router.on("routeDidChange", this, this.handleRouteChange);
    this.expandAncestorRouteNodes();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this, this.handleRouteChange);
  }

  @action
  handleRouteChange() {
    this.detailsHistory = [];
    this.expandAncestorRouteNodes();
  }

  @action
  expandAncestorRouteNodes() {
    const current = this.router.currentRouteName;
    const ancestorKeys = this._getAncestorNodeKeys(current);

    ancestorKeys.forEach((key) => {
      this.expandedRouteNodes.set(`application.${key}`, true);
    });

    // force reactivity
    this.expandedRouteNodes = new Map(this.expandedRouteNodes);
  }

  @action
  toggleVisibility() {
    this.isVisible = !this.isVisible;
    this.keyValueStore.setItem("route-inspector-visible", this.isVisible);
  }

  @action
  drillIntoDetails(key, value) {
    this.detailsHistory = [...this.detailsHistory, { key, value }];
  }

  @action
  goBackFromDetails() {
    if (this.detailsHistory.length > 0) {
      this.detailsHistory = this.detailsHistory.slice(0, -1);
    }
  }

  @action
  isSectionCollapsed(key, defaultCollapsed = false) {
    if (typeof defaultCollapsed !== "boolean") {
      defaultCollapsed = false;
    }
    if (this.filter) {
      if (this.filteredCollapseOverrides.has(key)) {
        return this.filteredCollapseOverrides.get(key);
      }
      return false;
    }
    if (!this.collapsedSections.has(key)) {
      return defaultCollapsed;
    }
    return this.collapsedSections.get(key);
  }

  @action
  toggleSection(key, defaultCollapsed = false) {
    // event objects can be passed as the second argument
    // when used with fn in templates, so this ensures
    // that defaultCollapsed is a boolean
    if (typeof defaultCollapsed !== "boolean") {
      defaultCollapsed = false;
    }
    if (this.filter) {
      const current =
        this.filteredCollapseOverrides.get(key) ??
        this.collapsedSections.get(key) ??
        false;
      this.filteredCollapseOverrides.set(key, !current);
      this.filteredCollapseOverrides = new Map(this.filteredCollapseOverrides);
      return;
    }
    const current = this.collapsedSections.get(key) ?? defaultCollapsed;
    this.collapsedSections.set(key, !current);
    this.collapsedSections = new Map(this.collapsedSections);
  }

  @action
  ensureSectionState(key, defaultCollapsed = false) {
    if (typeof defaultCollapsed !== "boolean") {
      defaultCollapsed = false;
    }
    if (!this.collapsedSections.has(key)) {
      this.collapsedSections.set(key, defaultCollapsed);
      this.collapsedSections = new Map(this.collapsedSections);
    }
  }

  @action
  setSectionCollapsedState(key, isCollapsed) {
    if (this.filter) {
      this.filteredCollapseOverrides.set(key, isCollapsed);
      this.filteredCollapseOverrides = new Map(this.filteredCollapseOverrides);
      return;
    }
    this.collapsedSections.set(key, isCollapsed);
    this.collapsedSections = new Map(this.collapsedSections);
  }

  get allSectionsExpanded() {
    if (this.filter) {
      for (const isCollapsed of this.filteredCollapseOverrides.values()) {
        if (isCollapsed === true) {
          return false;
        }
      }
      return true;
    }
    if (this.collapsedSections.size === 0) {
      return true;
    }

    for (const isCollapsed of this.collapsedSections.values()) {
      if (isCollapsed === true) {
        return false;
      }
    }

    return true;
  }

  get allSectionsCollapsed() {
    if (this.filter) {
      for (const isCollapsed of this.filteredCollapseOverrides.values()) {
        if (isCollapsed === false) {
          return false;
        }
      }
      return true;
    }
    if (this.collapsedSections.size === 0) {
      return true;
    }

    for (const isCollapsed of this.collapsedSections.values()) {
      if (isCollapsed === false) {
        return false;
      }
    }

    return true;
  }

  @action
  expandAllSections() {
    if (this.collapsedSections.size === 0) {
      return;
    }

    if (this.filter) {
      const overrides = new Map(this.filteredCollapseOverrides);
      for (const key of this.collapsedSections.keys()) {
        overrides.set(key, false);
      }
      this.filteredCollapseOverrides = overrides;
      return;
    }

    for (const key of this.collapsedSections.keys()) {
      this.collapsedSections.set(key, false);
    }

    this.collapsedSections = new Map(this.collapsedSections);
  }

  @action
  collapseAllSections() {
    if (this.collapsedSections.size === 0) {
      return;
    }

    if (this.filter) {
      const overrides = new Map(this.filteredCollapseOverrides);
      for (const key of this.collapsedSections.keys()) {
        overrides.set(key, true);
      }
      this.filteredCollapseOverrides = overrides;
      return;
    }

    for (const key of this.collapsedSections.keys()) {
      this.collapsedSections.set(key, true);
    }

    this.collapsedSections = new Map(this.collapsedSections);
  }

  _getAncestorNodeKeys(routeName) {
    if (!routeName) {
      return [];
    }

    const parts = routeName.replace(/^application\./, "").split(".");
    const keys = [];

    for (let i = 1; i <= parts.length; i++) {
      keys.push(parts.slice(0, i).join("."));
    }

    return keys;
  }

  @action
  isRouteNodeExpanded(nodeKey) {
    return this.expandedRouteNodes.get(nodeKey) ?? false;
  }

  @action
  toggleRouteNode(nodeKey) {
    const current = this.expandedRouteNodes.get(nodeKey) ?? false;
    this.expandedRouteNodes.set(nodeKey, !current);
    this.expandedRouteNodes = new Map(this.expandedRouteNodes);
  }

  @action
  shouldShowAllRouteNodes(nodeKey) {
    return this.showAllRouteNodes.has(nodeKey);
  }

  @action
  toggleShowAllRouteNodes(nodeKey) {
    if (this.showAllRouteNodes.has(nodeKey)) {
      this.showAllRouteNodes.delete(nodeKey);
    } else {
      this.showAllRouteNodes.add(nodeKey);
    }
    this.showAllRouteNodes = new Set(this.showAllRouteNodes);
  }

  @action
  setFilter(value) {
    const wasFiltering = !!this.filter;
    this.filter = value;
    if (value && !wasFiltering) {
      this.filteredCollapseOverrides = new Map();
    }
    if (!value) {
      this.filteredCollapseOverrides = new Map();
    }
  }

  @action
  toggleCaseSensitivity() {
    console.log("Toggling case sensitivity");
    this.filterCaseSensitive = !this.filterCaseSensitive;
  }
}
