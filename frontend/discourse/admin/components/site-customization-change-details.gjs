/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import SiteCustomizationChangeField from "discourse/admin/components/site-customization-change-field";
import { i18n } from "discourse-i18n";

@tagName("")
export default class SiteCustomizationChangeDetails extends Component {
  <template>
    <div ...attributes>
      <section class="field">
        <b>{{i18n "admin.customize.enabled"}}</b>:
        {{this.change.enabled}}
      </section>

      <SiteCustomizationChangeField
        @field={{this.change.stylesheet}}
        @name="admin.customize.css"
      />
      <SiteCustomizationChangeField
        @field={{this.change.mobile_stylesheet}}
        @icon="mobile"
        @name="admin.customize.css"
      />

      <SiteCustomizationChangeField
        @field={{this.change.header}}
        @name="admin.customize.header"
      />
      <SiteCustomizationChangeField
        @field={{this.change.mobile_header}}
        @icon="mobile"
        @name="admin.customize.header"
      />

      <SiteCustomizationChangeField
        @field={{this.change.top}}
        @name="admin.customize.top"
      />
      <SiteCustomizationChangeField
        @field={{this.change.mobile_top}}
        @icon="mobile"
        @name="admin.customize.top"
      />

      <SiteCustomizationChangeField
        @field={{this.change.footer}}
        @name="admin.customize.footer"
      />
      <SiteCustomizationChangeField
        @field={{this.change.mobile_footer}}
        @icon="mobile"
        @name="admin.customize.footer"
      />

      <SiteCustomizationChangeField
        @field={{this.change.head_tag}}
        @icon="file-text-o"
        @name="admin.customize.head_tag.text"
      />
      <SiteCustomizationChangeField
        @field={{this.change.body_tag}}
        @icon="file-text-o"
        @name="admin.customize.body_tag.text"
      />
    </div>
  </template>
}
