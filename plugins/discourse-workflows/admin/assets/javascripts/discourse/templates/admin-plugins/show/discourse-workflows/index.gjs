import WorkflowsIndex from "discourse/plugins/discourse-workflows/admin/components/workflows/index";

export default <template>
  <div class="admin-config-page__main-area">
    <WorkflowsIndex
      @workflows={{@controller.model.workflows}}
      @stats={{@controller.model.stats}}
    />
  </div>
</template>
