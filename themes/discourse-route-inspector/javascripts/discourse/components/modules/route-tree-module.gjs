import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { and, eq, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { highlightText } from "../../lib/highlight-text";
import { getDefaultCollapsed } from "../../lib/inspector-section-config";
import InspectorSection from "../inspector-section";

const MAX_VISIBLE_ITEMS = 10;

function sub(a, b) {
  return a - b;
}

class RouteTreeNode extends Component {
  @service router;
  @service routeInspectorState;

  @tracked isCollapsedFiltered = false;

  get normalizedCurrentRoute() {
    return (this.router.currentRouteName || "").replace(/^application\./, "");
  }

  get nodeKey() {
    return `application.${this.args.name}`;
  }

  get isExpanded() {
    if (this.routeInspectorState.filter) {
      return !this.isCollapsedFiltered;
    }
    return this.routeInspectorState.isRouteNodeExpanded(this.nodeKey);
  }

  get shouldShowAll() {
    return this.routeInspectorState.shouldShowAllRouteNodes(this.nodeKey);
  }

  get normalizedPath() {
    return this.args.path.replace(/^application\./, "");
  }

  get meta() {
    return this.args.children?.__meta || {};
  }

  get requiresParams() {
    return !!this.meta.requiresParams;
  }

  get paramNames() {
    return this.meta.paramNames || [];
  }

  get childEntries() {
    const children = this.args.children || {};
    const entries = Object.entries(children).filter(
      ([name]) => name !== "__meta"
    );

    const currentPath = this.router.currentRouteName || "";
    const sortedEntries = entries.sort(([nameA], [nameB]) => {
      const isAncestorA = currentPath.startsWith(nameA);
      const isAncestorB = currentPath.startsWith(nameB);

      if (isAncestorA && !isAncestorB) {
        return -1;
      }
      if (!isAncestorA && isAncestorB) {
        return 1;
      }
      return nameA.localeCompare(nameB);
    });

    return sortedEntries;
  }

  get visibleChildren() {
    if (this.shouldShowAll || this.childEntries.length <= MAX_VISIBLE_ITEMS) {
      return this.childEntries;
    }
    return this.childEntries.slice(0, MAX_VISIBLE_ITEMS);
  }

  get hasMoreChildren() {
    return !this.shouldShowAll && this.childEntries.length > MAX_VISIBLE_ITEMS;
  }

  get remainingCount() {
    return this.childEntries.length - MAX_VISIBLE_ITEMS;
  }

  get hasChildren() {
    return this.childEntries.length > 0;
  }

  get fullPath() {
    return this.args.path
      ? `${this.args.path}.${this.args.name}`
      : this.args.name;
  }

  get isCurrent() {
    return this.router.currentRouteName === this.args.name;
  }

  get isAncestor() {
    const current = this.router.currentRouteName;
    return (
      current === this.args.name || current.startsWith(this.args.name + ".")
    );
  }

  get decoratedName() {
    return highlightText(this.args.name, {
      query: this.routeInspectorState.filter,
      caseSensitive: this.routeInspectorState.filterCaseSensitive,
    });
  }

  get showTransitionButton() {
    return !this.isCurrent && !this.requiresParams;
  }

  @action
  toggleExpand() {
    if (this.hasChildren) {
      if (this.routeInspectorState.filter) {
        this.isCollapsedFiltered = !this.isCollapsedFiltered;
      } else {
        this.routeInspectorState.toggleRouteNode(this.nodeKey);
      }
    }
  }

  @action
  showAll() {
    this.routeInspectorState.toggleShowAllRouteNodes(this.nodeKey);
  }

  @action
  transitionTo() {
    if (this.requiresParams) {
      return;
    }
    this.router.transitionTo(this.args.name);
  }

  <template>
    <li
      class={{concatClass
        "route-tree__node"
        (if this.args.isBeforeShowAll "--last")
        (if this.hasChildren "--has-children")
      }}
    >
      {{#unless (eq this.args.name "application")}}
        <div class="route-tree__node-content">
          {{#if this.hasChildren}}
            <button
              type="button"
              class="route-tree__expand-btn"
              {{on "click" this.toggleExpand}}
            >
              {{icon (if this.isExpanded "caret-down" "caret-right")}}
            </button>
          {{else}}
            <span class="route-tree__expand-spacer"></span>
          {{/if}}

          <span class="route-tree__node-name {{if this.isCurrent '--current'}}">
            {{this.decoratedName}}
          </span>
          {{#if this.showTransitionButton}}
            <button
              type="button"
              class="route-tree__transition-btn"
              {{on "click" this.transitionTo}}
              title={{i18n
                (themePrefix "route_inspector.route_tree.transition_to")
              }}
            >
              {{icon "lucide-square-arrow-right"}}
            </button>
          {{else if this.requiresParams}}
            <button
              type="button"
              class="route-tree__transition-btn --disabled"
              disabled
              title={{i18n
                (themePrefix "route_inspector.route_tree.requires_params")
              }}
            >
              {{icon "lucide-square-arrow-right"}}
            </button>
          {{/if}}
        </div>
      {{/unless}}

      {{#if
        (and
          this.hasChildren
          (or this.isExpanded (eq this.args.name "application"))
        )
      }}
        <ul class="route-tree__children">
          {{#each this.visibleChildren as |child index|}}
            <RouteTreeNode
              @name={{child.[0]}}
              @children={{child.[1]}}
              @path={{this.fullPath}}
              @isBeforeShowAll={{and
                this.hasMoreChildren
                (eq index (sub this.visibleChildren.length 1))
              }}
            />
          {{/each}}

          {{#if this.hasMoreChildren}}
            <li class="route-tree__show-all">
              <span class="route-tree__expand-spacer"></span>
              <button
                type="button"
                class="route-tree__show-all-btn"
                {{on "click" this.showAll}}
              >
                {{i18n (themePrefix "route_inspector.route_tree.show_all")}}
                {{this.remainingCount}}
              </button>
            </li>
          {{/if}}
        </ul>
      {{/if}}
    </li>
  </template>
}

export default class RouteTreeModule extends Component {
  @service routeTree;
  @service routeInspectorState;

  get sectionKey() {
    return "route-tree";
  }

  get defaultCollapsed() {
    return getDefaultCollapsed(this.sectionKey);
  }

  get tree() {
    if (this.routeInspectorState.filter) {
      const filtered = this.filterNode(
        "application",
        this.routeTree.routeTree.application,
        this.routeInspectorState.filter,
        this.routeInspectorState.filterCaseSensitive
      );
      return filtered ? { application: filtered } : { application: {} };
    }
    return this.routeTree.routeTree;
  }

  get emptyTree() {
    return (
      !this.tree ||
      !this.tree.application ||
      Object.keys(this.tree.application).length === 0
    );
  }

  get filterActive() {
    return this.routeInspectorState.filter;
  }

  get isLong() {
    if (this.emptyTree) {
      return false;
    }

    const visibleRows = this.countVisibleRows(
      "application",
      this.tree.application,
      "",
      6
    );
    return visibleRows > 5;
  }

  countVisibleRows(nodeName, nodeChildren, path = "", limit = null) {
    let count = 0;

    if (nodeName !== "application") {
      count = 1;
      if (limit !== null && count >= limit) {
        return count;
      }
    }

    const children = nodeChildren || {};
    const childEntries = Object.entries(children).filter(
      ([name]) => name !== "__meta"
    );

    if (childEntries.length === 0) {
      return count;
    }

    const nodeKey = path ? `${path}.${nodeName}` : nodeName;
    const isExpanded = this.routeInspectorState.filter
      ? true
      : nodeName === "application" ||
        this.routeInspectorState.isRouteNodeExpanded(nodeKey);

    if (!isExpanded) {
      return count;
    }

    const shouldShowAll =
      this.routeInspectorState.shouldShowAllRouteNodes(nodeKey);
    const visibleCount =
      shouldShowAll || childEntries.length <= MAX_VISIBLE_ITEMS
        ? childEntries.length
        : MAX_VISIBLE_ITEMS;

    for (let i = 0; i < visibleCount; i++) {
      const [childName, childChildren] = childEntries[i];
      const fullPath = nodeKey || nodeName;
      count += this.countVisibleRows(
        childName,
        childChildren,
        fullPath,
        limit ? limit - count : null
      );

      if (limit !== null && count >= limit) {
        return count;
      }
    }

    if (!shouldShowAll && childEntries.length > MAX_VISIBLE_ITEMS) {
      count += 1;
    }

    return count;
  }

  matchesName(nodeName, query, caseSensitive) {
    if (!query) {
      return true;
    }

    const normalizedNodeName = caseSensitive
      ? nodeName
      : nodeName.toLowerCase();
    const normalizedQuery = caseSensitive ? query : query.toLowerCase();
    return normalizedNodeName.includes(normalizedQuery);
  }

  filterNode(nodeName, nodeChildren, query, caseSensitive) {
    const matches = this.matchesName(nodeName, query, caseSensitive);

    const filteredChildren = {};
    for (const [childName, childChildren] of Object.entries(
      nodeChildren || {}
    )) {
      if (childName === "__meta") {
        continue;
      }

      const filteredChild = this.filterNode(
        childName,
        childChildren,
        query,
        caseSensitive
      );
      if (filteredChild) {
        filteredChildren[childName] = filteredChild;
      }
    }

    if (matches || Object.keys(filteredChildren).length > 0) {
      if (nodeChildren?.__meta) {
        filteredChildren.__meta = nodeChildren.__meta;
      }
      return filteredChildren;
    }

    return null;
  }

  <template>
    <InspectorSection
      @label={{i18n (themePrefix "route_inspector.route_tree.title")}}
      @icon="lucide-network"
      @long={{this.isLong}}
      @sectionKey={{this.sectionKey}}
      @defaultCollapsed={{this.defaultCollapsed}}
      @isCollapsed={{@isCollapsed}}
      @onToggle={{@onToggle}}
    >
      <ul class="route-tree">
        {{#if this.emptyTree}}
          <span class="route-tree__empty">
            {{#if this.filterActive}}
              {{i18n (themePrefix "route_inspector.content.no_matches")}}
            {{else}}
              {{i18n (themePrefix "route_inspector.content.empty")}}
            {{/if}}
          </span>
        {{else}}
          <RouteTreeNode
            @name="application"
            @children={{this.tree.application}}
            @path=""
          />
        {{/if}}
      </ul>
    </InspectorSection>
  </template>
}
