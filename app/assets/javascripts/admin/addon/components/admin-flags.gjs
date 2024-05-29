import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";
import AdminFlagItem from "admin/components/admin-flag-item";

export default class AdminFlags extends Component {
  @service site;
  flags = this.site.flagTypes;

  <template>
    <div class="container admin-flags">
      <h1>{{i18n "admin.flags.title"}}</h1>
      <table class="flags grid">
        <thead>
          <th>{{i18n "admin.flags.description"}}</th>
          <th>{{i18n "admin.flags.enabled"}}</th>
        </thead>
        <tbody>
          {{#each this.flags as |flag|}}
            <AdminFlagItem @flag={{flag}} />
          {{/each}}
        </tbody>
      </table>
    </div>
  </template>
}
