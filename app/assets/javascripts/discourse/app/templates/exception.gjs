import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import { and } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <PluginOutlet
      @name="exception-wrapper"
      @outletArgs={{lazyHash thrown=this.thrown reason=this.reason}}
    >
      <div class="container">
        {{#if (and @controller.errorHtml @controller.isForbidden)}}
          <div class="not-found">{{htmlSafe @controller.errorHtml}}</div>
        {{else}}
          <div class="error-page">
            <div class="face">:(</div>
            <div class="reason">{{@controller.reason}}</div>
            {{#if @controller.requestUrl}}
              <div class="url">
                {{i18n "errors.prev_page"}}
                <a
                  href={{@controller.requestUrl}}
                  data-auto-route="true"
                >{{@controller.requestUrl}}</a>
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
                <DButton
                  @icon={{buttonData.icon}}
                  @action={{buttonData.action}}
                  @label={{buttonData.key}}
                  class={{buttonData.classes}}
                />
              {{/each}}
              <ConditionalLoadingSpinner @condition={{@controller.loading}} />
            </div>
          </div>
        {{/if}}
      </div>
    </PluginOutlet>
  </template>
);
