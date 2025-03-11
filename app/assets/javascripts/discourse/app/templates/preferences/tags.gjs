import RouteTemplate from "ember-route-template";
import SaveControls from "discourse/components/save-controls";
import Tags from "discourse/components/user-preferences/tags";

export default RouteTemplate(
  <template>
    <Tags
      @model={{@controller.model}}
      @selectedTags={{@controller.selectedTags}}
      @save={{@controller.save}}
      @siteSettings={{@controller.siteSettings}}
    />

    <SaveControls
      @model={{@controller.model}}
      @action={{@controller.save}}
      @saved={{@controller.saved}}
    />
  </template>
);
