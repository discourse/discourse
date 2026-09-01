import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import AdminInterpolationKeys from "discourse/admin/components/admin-interpolation-keys";
import withEventValue from "discourse/helpers/with-event-value";
import DButton from "discourse/ui-kit/d-button";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import DSaveControls from "discourse/ui-kit/d-save-controls";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="edit-site-text">
    <div class="title">
      <h3>{{@controller.siteText.id}}</h3>
    </div>

    <div class="title">
      <h4>{{i18n "admin.site_text.locale"}}
        {{@controller.localeFullName}}</h4>
    </div>

    {{#if @controller.isOutdated}}
      <div class="outdated">
        <h4>{{i18n "admin.site_text.outdated.title"}}</h4>
        <p>{{i18n "admin.site_text.outdated.description"}}</p>
        <h5>{{i18n "admin.site_text.outdated.old_default"}}</h5>
        <p>{{@controller.siteText.old_default}}</p>
        <h5>{{i18n "admin.site_text.outdated.new_default"}}</h5>
        <p>{{@controller.siteText.new_default}}</p>
        <DButton
          class="btn-default"
          @action={{@controller.dismissOutdated}}
          @label="admin.site_text.outdated.dismiss"
        />
      </div>
    {{/if}}

    <DExpandingTextArea
      class="site-text-value"
      rows="1"
      value={{@controller.buffered.value}}
      {{didInsert @controller.registerTextarea}}
      {{on "input" (withEventValue (fn (mut @controller.buffered.value)))}}
      {{on "focusin" @controller.trackTextarea}}
      {{on "focusout" @controller.saveCursorPos}}
    />

    <AdminInterpolationKeys
      @keys={{@controller.interpolationKeysWithStatus}}
      @onInsertKey={{@controller.insertInterpolationKey}}
    />

    <DSaveControls
      @action={{@controller.saveChanges}}
      @model={{@controller.siteText}}
      @saved={{@controller.saved}}
      @saveDisabled={{@controller.saveDisabled}}
    >
      {{#if @controller.siteText.can_revert}}
        <DButton
          class="revert-site-text"
          @action={{@controller.revertChanges}}
          @label="admin.site_text.revert"
        />
      {{/if}}
    </DSaveControls>

    <LinkTo
      class="go-back"
      @query={{hash locale=@controller.locale}}
      @route="adminSiteText.index"
    >
      {{dIcon "arrow-left"}}
      {{i18n "admin.site_text.go_back"}}
    </LinkTo>
  </div>
</template>
