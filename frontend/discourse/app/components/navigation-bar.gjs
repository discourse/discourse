import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import NavigationItem from "discourse/components/navigation-item";
import PluginOutlet from "discourse/components/plugin-outlet";
import DMenu from "discourse/float-kit/components/d-menu";
import lazyHash from "discourse/helpers/lazy-hash";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { applyValueTransformer } from "discourse/lib/transformer";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class NavigationBarComponent extends Component {
  @service site;

  get filterType() {
    return filterTypeForMode(this.args.filterMode);
  }

  get selectedNavItem() {
    const { navItems } = this.args;
    let item = navItems.find((i) => i.active === true);

    item = item || navItems.find((i) => i.filterType === this.filterType);

    return item || navItems[0];
  }

  get showDropdown() {
    return applyValueTransformer(
      "navigation-bar-dropdown-mode",
      this.site.mobileView
    );
  }

  get navigationBarIcon() {
    return applyValueTransformer(
      "navigation-bar-dropdown-icon",
      "discourse-chevron-expand"
    );
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    <ul class="nav nav-pills" id="navigation-bar">
      {{#if this.showDropdown}}
        <li>
          <DMenu
            @autofocus={{true}}
            @identifier="list-control-toggle-link"
            @modalForMobile={{true}}
            @onRegisterApi={{this.onRegisterApi}}
          >
            <:trigger>
              <span
                class="list-control-toggle-link__text"
              >{{this.selectedNavItem.displayName}}</span>
              {{dIcon this.navigationBarIcon}}
            </:trigger>

            <:content>
              <DDropdownMenu {{on "click" this.dMenu.close}} as |dropdown|>
                {{#each @navItems as |navItem|}}
                  <NavigationItem
                    class={{concat "nav-item_" navItem.name}}
                    @category={{@category}}
                    @content={{navItem}}
                    @filterMode={{@filterMode}}
                  />

                {{/each}}
                <dropdown.item>
                  <PluginOutlet
                    @connectorTagName="span"
                    @name="extra-nav-item"
                    @outletArgs={{lazyHash
                      category=@category
                      tag=@tag
                      filterMode=@filterMode
                    }}
                  />
                </dropdown.item>
              </DDropdownMenu>
            </:content>
          </DMenu>
        </li>
        <li>
          <PluginOutlet
            @connectorTagName="span"
            @name="inline-extra-nav-item"
            @outletArgs={{lazyHash category=@category filterMode=@filterMode}}
          />
        </li>
      {{else}}
        {{#each @navItems as |navItem|}}
          <NavigationItem
            class={{concat "nav-item_" navItem.name}}
            @category={{@category}}
            @content={{navItem}}
            @filterMode={{@filterMode}}
          />
        {{/each}}
        <PluginOutlet
          @connectorTagName="li"
          @name="extra-nav-item"
          @outletArgs={{lazyHash
            category=@category
            tag=@tag
            filterMode=@filterMode
          }}
        />

      {{/if}}
    </ul>
  </template>
}
