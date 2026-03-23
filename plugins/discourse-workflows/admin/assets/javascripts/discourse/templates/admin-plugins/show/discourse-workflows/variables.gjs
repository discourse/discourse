import htmlClass from "discourse/helpers/html-class";
import VariablesManager from "discourse/plugins/discourse-workflows/admin/components/workflows/variable/manager";

export default <template>
  {{htmlClass "workflows-page"}}
  <div class="admin-config-page__main-area">
    <VariablesManager />
  </div>
</template>
