import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";

export default class UserTipContainer extends Component {
  @service userTips;

  get safeHtmlContent() {
    return htmlSafe(this.args.data.contentHtml);
  }

  @action
  handleDismiss(_, event) {
    event.preventDefault();
    this.args.close();
    this.userTips.hideUserTipForever(this.args.data.id);
  }

  <template>
    <div class="user-tip__container">
      <div class="user-tip__title">{{@data.titleText}}</div>
      <div class="user-tip__content">
        {{#if @data.contentHtml}}
          {{this.safeHtmlContent}}
        {{else}}
          {{@data.contentText}}
        {{/if}}
      </div>
      {{#if @data.onDismiss}}
        <div class="user-tip__buttons">
          <DButton
            class="btn-primary"
            @translatedLabel={{@data.buttonText}}
            @action={{this.handleDismiss}}
            @forwardEvent={{true}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
