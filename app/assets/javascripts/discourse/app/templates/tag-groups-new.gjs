import RouteTemplate from "ember-route-template";
import TagGroupsForm from "discourse/components/tag-groups-form";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template>
  <div class="tag-group-content">
    <h3>{{iN "tagging.groups.new_title"}}</h3>
    <TagGroupsForm @model={{@controller.model}} @onSave={{action "onSave"}} />
  </div>
</template>);
