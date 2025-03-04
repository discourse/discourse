import RouteTemplate from 'ember-route-template';
import TagGroupsForm from "discourse/components/tag-groups-form";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template><div class="tag-group-content">
  <h3>{{iN "tagging.groups.edit_title"}}</h3>
  <TagGroupsForm @model={{@controller.model}} @onDestroy={{action "onDestroy"}} />
</div></template>);