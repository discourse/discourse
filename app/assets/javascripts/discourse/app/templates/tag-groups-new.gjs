import RouteTemplate from 'ember-route-template'
import iN from "discourse/helpers/i18n";
import TagGroupsForm from "discourse/components/tag-groups-form";
export default RouteTemplate(<template><div class="tag-group-content">
  <h3>{{iN "tagging.groups.new_title"}}</h3>
  <TagGroupsForm @model={{@controller.model}} @onSave={{action "onSave"}} />
</div></template>)