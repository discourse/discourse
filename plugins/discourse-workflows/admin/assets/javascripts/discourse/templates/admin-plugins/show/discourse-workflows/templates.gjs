import WorkflowsTemplates from "discourse/plugins/discourse-workflows/admin/components/workflows/templates";

export default <template>
  <div class="admin-config-page__main-area">
    <WorkflowsTemplates @templates={{@controller.model.templates}} />
  </div>
</template>
