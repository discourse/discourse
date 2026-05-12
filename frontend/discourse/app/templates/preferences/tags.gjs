import Tags from "discourse/components/user-preferences/tags";
import DSaveControls from "discourse/ui-kit/d-save-controls";

export default <template>
  <Tags
    @model={{@controller.model}}
    @selectedTags={{@controller.selectedTags}}
    @save={{@controller.save}}
    @siteSettings={{@controller.siteSettings}}
  />

  <DSaveControls
    @model={{@controller.model}}
    @action={{@controller.save}}
    @saved={{@controller.saved}}
  />
</template>
