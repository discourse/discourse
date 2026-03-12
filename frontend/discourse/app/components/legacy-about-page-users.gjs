import Component from "@glimmer/component";
import UserInfo from "discourse/ui-kit/d-user-info";

export default class LegacyAboutPageUsers extends Component {
  get users() {
    return this.args.users || [];
  }

  <template>
    {{#each this.users as |user|}}
      <UserInfo @user={{user}} />
    {{/each}}
  </template>
}
