import Component from "@glimmer/component";
import SiteSettingComponent from "discourse/admin/components/site-setting";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";

export default class DiscourseAiFeatureEditor extends Component {
  subheaderLabel(name) {
    return i18n("discourse_ai.features.subheading", {
      module_name: name,
    });
  }

  <template>
    <div class="admin-detail">
      <DPageSubheader @titleLabel={{this.subheaderLabel @model.module_name}} />

      <section class="ai-feature-editor">

        {{#each @model.feature_settings as |setting|}}
          <div>
            <SiteSettingComponent @setting={{setting}} />
          </div>
        {{/each}}
      </section>
    </div>
  </template>
}
