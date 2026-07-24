import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <PluginOutlet
    @name="exception-wrapper"
    @outletArgs={{lazyHash thrown=this.thrown reason=this.reason}}
  >
    <div class="container">
      {{#if (and @controller.errorHtml @controller.isForbidden)}}
        <div class="not-found">{{trustHTML @controller.errorHtml}}</div>
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
              {{dIcon "circle-check"}}
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
            <DConditionalLoadingSpinner @condition={{@controller.loading}} />
          </div>
        </div>
      {{/if}}
    </div>
  </PluginOutlet>
</template>
