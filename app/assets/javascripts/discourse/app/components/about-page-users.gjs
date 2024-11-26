import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import AboutPageUser from "discourse/components/about-page-user";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class AboutPageUsers extends Component {
  @tracked expanded = false;

  get users() {
    let users = this.args.users;
    if (this.showViewMoreButton && !this.expanded) {
      users = users.slice(0, this.args.truncateAt);
    }
    return users;
  }

  get showViewMoreButton() {
    return (
      this.args.truncateAt > 0 && this.args.users.length > this.args.truncateAt
    );
  }

  @action
  toggleExpanded() {
    this.expanded = !this.expanded;
  }

  <template>
    <div class="about-page-users-list">
      {{#each this.users as |user|}}
        <AboutPageUser @user={{user}} />
      {{/each}}
    </div>
    {{#if this.showViewMoreButton}}
      <DButton
        class="btn-flat about-page-users-list__expand-button"
        @action={{this.toggleExpanded}}
        @icon={{if this.expanded "chevron-up" "chevron-down"}}
        @translatedLabel={{if
          this.expanded
          (i18n "about.view_less")
          (i18n "about.view_more")
        }}
      />
    {{/if}}
  </template>
}
