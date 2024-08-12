import Component from "@glimmer/component";
import AboutPageUser from "discourse/components/about-page-user";

export default class LegacyAboutPageUsers extends Component {
  get users() {
    return this.args.users || [];
  }

  <template>
    {{#each this.users as |user|}}
      <AboutPageUser @user={{user}} />
    {{/each}}
  </template>
}
