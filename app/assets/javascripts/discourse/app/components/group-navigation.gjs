import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import GroupDropdown from "select-kit/components/group-dropdown";

export default class GroupNavigation extends Component {
  @service site;

  <template>
    {{#if this.site.desktopView}}
      <GroupDropdown
        @groups={{@group.extras.visible_group_names}}
        @value={{@group.name}}
      />
    {{/if}}
    <HorizontalOverflowNav class="group-nav">
      {{#if this.site.mobileView}}
        <li>
          <LinkTo @route="groups.index">
            {{i18n "groups.index.all"}}
          </LinkTo>
        </li>
      {{/if}}
      {{#each @tabs as |tab|}}
        <li>
          <LinkTo
            @route={{tab.route}}
            @model={{@group}}
            title={{tab.message}}
            class={{tab.name}}
          >
            {{#if tab.icon}}
              {{icon tab.icon}}
            {{/if}}
            {{tab.message}}
            {{#if tab.count}}
              <span class="count">
                ({{tab.count}})
              </span>
            {{/if}}
          </LinkTo>
        </li>
      {{/each}}
      <PluginOutlet
        @name="group-reports-nav-item"
        @outletArgs={{lazyHash group=@group}}
        @connectorTagName="li"
      />
    </HorizontalOverflowNav>
  </template>
}
