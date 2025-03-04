import RouteTemplate from 'ember-route-template';
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import dIcon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import iN from "discourse/helpers/i18n";
import and from "truth-helpers/helpers/and";
export default RouteTemplate(<template><div class="container">
  {{#if (and @controller.errorHtml @controller.isForbidden)}}
    <div class="not-found">{{htmlSafe @controller.errorHtml}}</div>
  {{else}}
    <div class="error-page">
      <div class="face">:(</div>
      <div class="reason">{{@controller.reason}}</div>
      {{#if @controller.requestUrl}}
        <div class="url">
          {{iN "errors.prev_page"}}
          <a href={{@controller.requestUrl}} data-auto-route="true">{{@controller.requestUrl}}</a>
        </div>
      {{/if}}
      <div class="desc">
        {{#if @controller.networkFixed}}
          {{dIcon "circle-check"}}
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
</div></template>);