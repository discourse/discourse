import Component from "@glimmer/component";
import { service } from "@ember/service";
import UserFieldsList from "discourse/admin/components/admin-config-areas/user-fields-list";
import UserFieldsListReorderable from "discourse/admin/components/admin-config-areas/user-fields-list-reorderable";

// TODO (ui-kit-reorderable-list-cleanup) delete this switch and render
// `UserFieldsList` directly once `enable_new_reordering_controls` ships.
class UserFieldsSwitch extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.enable_new_reordering_controls}}
      <UserFieldsListReorderable @userFields={{@userFields}} />
    {{else}}
      <UserFieldsList @userFields={{@userFields}} />
    {{/if}}
  </template>
}

export default <template>
  <UserFieldsSwitch @userFields={{@controller.model}} />
</template>
