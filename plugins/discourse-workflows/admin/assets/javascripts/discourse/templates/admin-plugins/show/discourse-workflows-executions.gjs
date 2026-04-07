import htmlClass from "discourse/helpers/html-class";
import ExecutionsManager from "discourse/plugins/discourse-workflows/admin/components/workflows/execution/manager";

export default <template>
  {{htmlClass "workflows-page"}}
  <div class="admin-config-page__main-area">
    <ExecutionsManager />
  </div>
</template>
