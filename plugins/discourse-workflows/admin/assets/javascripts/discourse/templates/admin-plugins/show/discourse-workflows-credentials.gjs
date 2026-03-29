import htmlClass from "discourse/helpers/html-class";
import CredentialsManager from "discourse/plugins/discourse-workflows/admin/components/workflows/credential/manager";

export default <template>
  {{htmlClass "workflows-page"}}
  <div class="admin-config-page__main-area">
    <CredentialsManager />
  </div>
</template>
