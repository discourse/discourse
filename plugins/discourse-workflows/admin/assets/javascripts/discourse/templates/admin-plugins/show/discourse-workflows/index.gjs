import htmlClass from "discourse/helpers/html-class";
import WorkflowsIndex from "discourse/plugins/discourse-workflows/admin/components/workflows/index";

export default <template>
  {{htmlClass "workflows-page"}}
  <div class="admin-config-page__main-area">
    <WorkflowsIndex
      @workflows={{@controller.model.workflows}}
      @stats={{@controller.model.stats}}
    />
  </div>
</template>
