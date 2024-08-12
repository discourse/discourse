import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import DropdownMenu from "discourse/components/dropdown-menu";
import NavigationItem from "discourse/components/navigation-item";
import PluginOutlet from "discourse/components/plugin-outlet";
import concat from "discourse/helpers/concat-class";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import icon from "discourse-common/helpers/d-icon";
import DMenu from "float-kit/components/d-menu";

export default class NavigationBarComponent extends Component {
  @service site;

  @tracked expanded = false;
  @tracked filterMode;

  constructor() {
    super(...arguments);
  }

  @dependentKeyCompat
  get filterType() {
    return filterTypeForMode(this.filterMode);
  }

  get selectedNavItem() {
    let { filterType, navItems, connectors, category } = this.args;
    let item = navItems.find((i) => i.active === true);

    item = item || navItems.find((i) => i.filterType === filterType);

    if (!item && connectors && category) {
      connectors.forEach((c) => {
        if (
          c.connectorClass &&
          typeof c.connectorClass.path === "function" &&
          typeof c.connectorClass.displayName === "function"
        ) {
          let path = c.connectorClass.path(category);
          if (path.includes(filterType)) {
            item = {
              displayName: c.connectorClass.displayName(),
            };
          }
        }
      });
    }
    return item || navItems[0];
  }

  get classNames() {
    return ["nav", "nav-pills"];
  }

  willDestroy() {
    super.willDestroy(...arguments);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    <ul id="navigation-bar" class="nav nav-pills">
      {{#if this.site.mobileView}}
        <li>
          <DMenu
            @modalForMobile={{true}}
            @autofocus={{true}}
            @identifier="list-control-toggle-link"
            @onRegisterApi={{this.onRegisterApi}}
          >
            <:trigger>
              <span
                class="list-control-toggle-link__text"
              >{{this.selectedNavItem.displayName}}</span>
              {{icon "discourse-chevron-expand"}}
            </:trigger>

            <:content>
              <DropdownMenu as |dropdown|>
                {{#each this.args.navItems as |navItem|}}
                  <dropdown.item>
                    <NavigationItem
                      @content={{navItem}}
                      @filterMode={{this.filterMode}}
                      @category={{this.category}}
                      class={{concat "nav-item_" navItem.name}}
                    />
                  </dropdown.item>
                {{/each}}
                <dropdown.item>
                  <PluginOutlet
                    @name="extra-nav-item"
                    @connectorTagName="span"
                    @outletArgs={{hash
                      category=this.category
                      tag=this.tag
                      filterMode=this.filterMode
                    }}
                  />
                </dropdown.item>
              </DropdownMenu>
            </:content>
          </DMenu>
        </li>
        <li>
          <PluginOutlet
            @name="inline-extra-nav-item"
            @connectorTagName="span"
            @outletArgs={{hash
              category=this.category
              filterMode=this.filterMode
            }}
          />
        </li>

      {{else}}
        {{#each this.args.navItems as |navItem|}}
          <NavigationItem
            @content={{navItem}}
            @filterMode={{this.filterMode}}
            @category={{this.category}}
            class={{concat "nav-item_" navItem.name}}
          />
        {{/each}}
        <PluginOutlet
          @name="extra-nav-item"
          @connectorTagName="li"
          @outletArgs={{hash
            category=this.category
            tag=this.tag
            filterMode=this.filterMode
          }}
        />

      {{/if}}
    </ul>
  </template>
}
