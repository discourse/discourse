import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import AboutPageUsers from "discourse/components/about-page-users";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { ajax } from "discourse/lib/ajax";

export default class AboutPageExtraGroups extends Component {
  @service store;
  @service site;
  @service siteSettings;

  @tracked groups = [];
  @tracked loading = false;

  constructor() {
    super(...arguments);
    this.loadGroups();
  }

  groupName(group) {
    return group.full_name || group.name.replace(/[_-]/g, " ");
  }

  @action
  async loadGroups() {
    this.loading = true;
    try {
      const groupsSetting =
        this.siteSettings.about_page_extra_groups?.split("|").map(Number) || [];

      let groupsToFetch = this.site.groups.filter((group) =>
        groupsSetting.includes(group.id)
      );

      // ordered alphabetically by default
      if (
        this.siteSettings.about_page_extra_groups_order === "order of creation"
      ) {
        groupsToFetch.sort((a, b) => a.id - b.id);
      } else if (
        this.siteSettings.about_page_extra_groups_order ===
        "order of theme setting"
      ) {
        groupsToFetch.sort(
          (a, b) => groupsSetting.indexOf(a.id) - groupsSetting.indexOf(b.id)
        );
      }

      const groupPromises = groupsToFetch.map(async (group) => {
        try {
          const groupDetails = await this.loadGroupDetails(group.name);
          group.members = await this.loadGroupMembers(group.name);
          Object.assign(group, groupDetails);
          return group;
        } catch (error) {
          // eslint-disable-next-line no-console
          console.error(
            `Error loading members for group ${group.name}:`,
            error
          );
          return null;
        }
      });

      const groupsWithMembers = (await Promise.all(groupPromises)).filter(
        (group) => group && group.members.length > 0
      );

      this.groups = groupsWithMembers;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Error loading groups:", error);
      this.groups = [];
    } finally {
      this.loading = false;
    }
  }

  async loadGroupDetails(groupName) {
    try {
      const response = await ajax(`/g/${groupName}`);
      return response.group;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(`Error loading details for group ${groupName}:`, error);
      return "";
    }
  }

  async loadGroupMembers(groupName) {
    try {
      const response = await ajax(`/g/${groupName}/members?asc=true`);
      return response.members || [];
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(`Error loading members for group ${groupName}:`, error);
      return [];
    }
  }

  get showGroupDescription() {
    return this.siteSettings.about_page_extra_groups_show_description;
  }

  get showInitialMembers() {
    return this.siteSettings.about_page_extra_groups_initial_members;
  }

  <template>
    <ConditionalLoadingSpinner @condition={{this.loading}}>
      {{#if this.groups}}
        {{#each this.groups as |group|}}
          <section
            class="about__{{group.name}}
              --custom-group
              {{if this.showGroupDescription '--has-description'}}"
          >
            <h3>
              <a href="/g/{{group.name}}">{{this.groupName group}}</a>
            </h3>
            {{#if this.showGroupDescription}}
              <p>{{htmlSafe group.bio_cooked}}</p>
            {{/if}}
            <AboutPageUsers
              @users={{group.members}}
              @truncateAt={{this.showInitialMembers}}
            />
          </section>
        {{/each}}
      {{/if}}
    </ConditionalLoadingSpinner>
  </template>
}
