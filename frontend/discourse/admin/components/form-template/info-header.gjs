import { i18n } from "discourse-i18n";

const InfoHeader = <template>
  <div class="form-templates--info">
    <h2>{{i18n "admin.form_templates.title"}}</h2>
    <p class="desc">{{i18n "admin.form_templates.help"}}</p>
  </div>
</template>;

export default InfoHeader;
