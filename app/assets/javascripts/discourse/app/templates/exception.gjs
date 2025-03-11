import RouteTemplate from 'ember-route-template'
import and from "truth-helpers/helpers/and";
import htmlSafe from "discourse/helpers/html-safe";
import i18n from "discourse/helpers/i18n";
import icon from "discourse/helpers/d-icon";
import DButton from "discourse/components/d-button";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
export default RouteTemplate(<template><div class="container">
  {{#if (and @controller.errorHtml @controller.isForbidden)}}
    <div class="not-found">{{htmlSafe @controller.errorHtml}}</div>
  {{else}}
    <div class="error-page">
      <div class="face">:(</div>
      <div class="reason">{{@controller.reason}}</div>
      {{#if @controller.requestUrl}}
        <div class="url">
          {{i18n "errors.prev_page"}}
          <a href={{@controller.requestUrl}} data-auto-route="true">{{@controller.requestUrl}}</a>
        </div>
      {{/if}}
      <div class="desc">
        {{#if @controller.networkFixed}}
          {{icon "circle-check"}}
        {{/if}}

        {{@controller.desc}}
      </div>
      <div class="buttons">
        {{#each @controller.enabledButtons as |buttonData|}}
          <DButton @icon={{buttonData.icon}} @action={{buttonData.action}} @label={{buttonData.key}} class={{buttonData.classes}} />
        {{/each}}
        <ConditionalLoadingSpinner @condition={{@controller.loading}} />
      </div>
    </div>
  {{/if}}
</div></template>)