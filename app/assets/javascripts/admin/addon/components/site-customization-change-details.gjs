import Component from "@ember/component";
import { i18n } from "discourse-i18n";
import SiteCustomizationChangeField from "admin/components/site-customization-change-field";

export default class SiteCustomizationChangeDetails extends Component {
  <template>
    <section class="field">
      <b>{{i18n "admin.customize.enabled"}}</b>:
      {{this.change.enabled}}
    </section>

    <SiteCustomizationChangeField
      @field={{this.change.stylesheet}}
      @name="admin.customize.css"
    />
    <SiteCustomizationChangeField
      @icon="mobile"
      @field={{this.change.mobile_stylesheet}}
      @name="admin.customize.css"
    />

    <SiteCustomizationChangeField
      @field={{this.change.header}}
      @name="admin.customize.header"
    />
    <SiteCustomizationChangeField
      @icon="mobile"
      @field={{this.change.mobile_header}}
      @name="admin.customize.header"
    />

    <SiteCustomizationChangeField
      @field={{this.change.top}}
      @name="admin.customize.top"
    />
    <SiteCustomizationChangeField
      @icon="mobile"
      @field={{this.change.mobile_top}}
      @name="admin.customize.top"
    />

    <SiteCustomizationChangeField
      @field={{this.change.footer}}
      @name="admin.customize.footer"
    />
    <SiteCustomizationChangeField
      @icon="mobile"
      @field={{this.change.mobile_footer}}
      @name="admin.customize.footer"
    />

    <SiteCustomizationChangeField
      @icon="file-text-o"
      @field={{this.change.head_tag}}
      @name="admin.customize.head_tag.text"
    />
    <SiteCustomizationChangeField
      @icon="file-text-o"
      @field={{this.change.body_tag}}
      @name="admin.customize.body_tag.text"
    />
  </template>
}
