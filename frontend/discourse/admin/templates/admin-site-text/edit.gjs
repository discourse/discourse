import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/components/d-button";
import ExpandingTextArea from "discourse/components/expanding-text-area";
import SaveControls from "discourse/components/save-controls";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
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
          @action={{@controller.dismissOutdated}}
          @label="admin.site_text.outdated.dismiss"
          class="btn-default"
        />
      </div>
    {{/if}}

    <ExpandingTextArea
      {{on "input" (withEventValue (fn (mut @controller.buffered.value)))}}
      value={{@controller.buffered.value}}
      rows="1"
      class="site-text-value"
    />

    {{#if @controller.interpolationKeysWithStatus.length}}
      <div class="interpolation-keys">
        {{i18n "admin.site_text.interpolation_keys"}}
        {{#each @controller.interpolationKeysWithStatus as |item|}}
          <span class={{if item.isUsed "used"}}>{{item.key}}</span>
        {{/each}}
      </div>
    {{/if}}

    <SaveControls
      @model={{@controller.siteText}}
      @action={{@controller.saveChanges}}
      @saved={{@controller.saved}}
      @saveDisabled={{@controller.saveDisabled}}
    >
      {{#if @controller.siteText.can_revert}}
        <DButton
          @action={{@controller.revertChanges}}
          @label="admin.site_text.revert"
          class="revert-site-text"
        />
      {{/if}}
    </SaveControls>

    <LinkTo
      @route="adminSiteText.index"
      @query={{hash locale=@controller.locale}}
      class="go-back"
    >
      {{icon "arrow-left"}}
      {{i18n "admin.site_text.go_back"}}
    </LinkTo>
  </div>
</template>
