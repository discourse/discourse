import Tags from "discourse/components/user-preferences/tags";
import DSaveControls from "discourse/ui-kit/d-save-controls";

export default <template>
  <Tags
    @model={{@controller.model}}
    @save={{@controller.save}}
    @selectedTags={{@controller.selectedTags}}
    @siteSettings={{@controller.siteSettings}}
  />

  <DSaveControls
    @action={{@controller.save}}
    @model={{@controller.model}}
    @saved={{@controller.saved}}
  />
</template>
