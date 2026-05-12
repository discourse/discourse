import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import GroupDropdown from "discourse/select-kit/components/group-dropdown";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class GroupNavigation extends Component {
  @service site;

  <template>
    {{#if this.site.desktopView}}
      <GroupDropdown
        @groups={{@group.extras.visible_group_names}}
        @value={{@group.name}}
      />
    {{/if}}
    <DHorizontalOverflowNav class="group-nav">
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
              {{dIcon tab.icon}}
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
    </DHorizontalOverflowNav>
  </template>
}
