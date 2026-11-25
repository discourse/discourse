import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import DiscourseURL from "discourse/lib/url";
import GroupDropdown from "discourse/select-kit/components/group-dropdown";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The "All groups" row's value; a group name can't start with `*`. */
const ALL_GROUPS = "*all";

export default class GroupNavigation extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  /** The groups the page was given, as the site's records where it knows them. */
  get switcherGroups() {
    const known = new Map(
      (this.site.groups ?? []).map((group) => [group.name, group])
    );
    return (this.args.group.extras?.visible_group_names ?? []).map(
      (name) => known.get(name) ?? { name }
    );
  }

  /** "All groups" leads the list while browsing, when the directory is open to the viewer. */
  @action
  switcherExtraOptions(snapshot) {
    if (
      snapshot.filter ||
      (!this.siteSettings.enable_group_directory && !this.currentUser?.staff)
    ) {
      return [];
    }
    return [
      selectOption({ name: ALL_GROUPS }, { label: i18n("groups.index.all") }),
    ];
  }

  @action
  switchGroup(name) {
    DiscourseURL.routeToUrl(name === ALL_GROUPS ? "/g" : `/g/${name}`);
  }

  <template>
    {{#if this.site.desktopView}}
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectGroup
          @caretIcon={{hash open="angle-down" closed="angle-right"}}
          @emit="names"
          @extraOptions={{this.switcherExtraOptions}}
          @identifier="group-dropdown"
          @legacyKind="group-dropdown"
          @onChange={{this.switchGroup}}
          @options={{this.switcherGroups}}
          @value={{@group.name}}
          @variant="button"
        />
      {{else}}
        <GroupDropdown
          @groups={{@group.extras.visible_group_names}}
          @value={{@group.name}}
        />
      {{/if}}
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
            class={{tab.name}}
            title={{tab.message}}
            @model={{@group}}
            @route={{tab.route}}
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
        @connectorTagName="li"
        @name="group-reports-nav-item"
        @outletArgs={{lazyHash group=@group}}
      />
    </DHorizontalOverflowNav>
  </template>
}
