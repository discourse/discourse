import Tags from "discourse/components/user-preferences/tags";
import SaveControls from "discourse/ui-kit/d-save-controls";

export default <template>
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
