import RouteTemplate from "ember-route-template";
import TagGroupsForm from "discourse/components/tag-groups-form";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="tag-group-content">
      <h3>{{i18n "tagging.groups.edit_title"}}</h3>
      <TagGroupsForm
        @model={{@controller.model}}
        @onDestroy={{@controller.onDestroy}}
      />
    </div>
  </template>
);
