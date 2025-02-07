import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import GroupDropdown from "select-kit/components/group-dropdown";

const GroupNavigation = <template>
  {{#if this.site.mobileView}}
    <LinkTo @route="groups.index">
      {{i18n "groups.index.all"}}
    </LinkTo>
  {{else}}
    <GroupDropdown
      @groups={{@group.extras.visible_group_names}}
      @value={{@group.name}}
    />
  {{/if}}
  <HorizontalOverflowNav class="group-nav">
    {{#each @tabs as |tab|}}
      <li>
        <LinkTo
          @route={{tab.route}}
          @model={{@group}}
          title={{tab.message}}
          class={{tab.name}}
        >
          {{#if tab.icon}}{{icon tab.icon}}{{/if}}
          {{tab.message}}
          {{#if tab.count}}<span class="count">({{tab.count}})</span>{{/if}}
        </LinkTo>
      </li>
    {{/each}}
    <PluginOutlet
      @name="group-reports-nav-item"
      @outletArgs={{hash group=@group}}
      @connectorTagName="li"
    />
  </HorizontalOverflowNav>
</template>;

export default GroupNavigation;
