import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import AdminInterpolationKeys from "discourse/admin/components/admin-interpolation-keys";
import withEventValue from "discourse/helpers/with-event-value";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import DPageHeader from "discourse/ui-kit/d-page-header";
import DSaveControls from "discourse/ui-kit/d-save-controls";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="edit-site-text">
    <DPageHeader
      @hideTabs={{true}}
      @shouldDisplay={{true}}
      @titleLabel={{i18n "admin.site_text.edit_title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.site_texts.title"}}
          @path="/admin/customize/site_texts"
        />
      </:breadcrumbs>
    </DPageHeader>
    <LinkTo
      class="go-back"
      @query={{hash locale=@controller.locale theme_id=@controller.themeId}}
      @route="adminSiteText.index"
    >
      {{dIcon "arrow-left"}}
      {{i18n "admin.site_text.go_back"}}
    </LinkTo>
    <code class="edit-site-text__key">{{@controller.siteText.id}}</code>

    {{#if @controller.isInvalid}}
      <div class="outdated" role="status">
        <h4>{{i18n "admin.site_text.invalid_title"}}</h4>
        <p>{{i18n "admin.site_text.invalid_description"}}</p>
      </div>
    {{/if}}

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

    {{#unless @controller.isOutdated}}
      {{#if @controller.defaultText}}
        <div class="edit-site-text__default">
          <h2>{{i18n "admin.site_text.default_text"}}</h2>
          <p>{{@controller.defaultText}}</p>
        </div>
      {{/if}}
    {{/unless}}

    <label class="edit-site-text__value-label" for="site-text-value">{{i18n
        "admin.site_text.value_label"
        language=@controller.localeFullName
      }}</label>
    <DExpandingTextArea
      class="site-text-value"
      id="site-text-value"
      rows="5"
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
  </div>
</template>
