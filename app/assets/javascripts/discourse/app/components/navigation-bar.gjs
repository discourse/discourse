import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DropdownMenu from "discourse/components/dropdown-menu";
import NavigationItem from "discourse/components/navigation-item";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { applyValueTransformer } from "discourse/lib/transformer";
import DMenu from "float-kit/components/d-menu";

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
    <ul id="navigation-bar" class="nav nav-pills">
      {{#if this.showDropdown}}
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
              {{icon this.navigationBarIcon}}
            </:trigger>

            <:content>
              <DropdownMenu {{on "click" this.dMenu.close}} as |dropdown|>
                {{#each @navItems as |navItem|}}
                  <NavigationItem
                    @content={{navItem}}
                    @filterMode={{@filterMode}}
                    @category={{@category}}
                    class={{concat "nav-item_" navItem.name}}
                  />

                {{/each}}
                <dropdown.item>
                  <PluginOutlet
                    @name="extra-nav-item"
                    @connectorTagName="span"
                    @outletArgs={{hash
                      category=@category
                      tag=@tag
                      filterMode=@filterMode
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
            @outletArgs={{hash category=@category filterMode=@filterMode}}
          />
        </li>
      {{else}}
        {{#each @navItems as |navItem|}}
          <NavigationItem
            @content={{navItem}}
            @filterMode={{@filterMode}}
            @category={{@category}}
            class={{concat "nav-item_" navItem.name}}
          />
        {{/each}}
        <PluginOutlet
          @name="extra-nav-item"
          @connectorTagName="li"
          @outletArgs={{hash
            category=@category
            tag=@tag
            filterMode=@filterMode
          }}
        />

      {{/if}}
    </ul>
  </template>
}
