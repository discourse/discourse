import Component from "@glimmer/component";
import { service } from "@ember/service";
import Flags from "discourse/admin/components/admin-config-areas/flags";
import FlagsReorderable from "discourse/admin/components/admin-config-areas/flags-reorderable";

// TODO (ui-kit-reorderable-list-cleanup) delete this switch and render
// `Flags` directly once `enable_new_reordering_controls` ships.
class FlagsSwitch extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.enable_new_reordering_controls}}
      <FlagsReorderable />
    {{else}}
      <Flags />
    {{/if}}
  </template>
}

export default <template><FlagsSwitch /></template>
