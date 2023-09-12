import { htmlSafe } from "@ember/template";
import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import { action } from "@ember/object";

export default class UserTipContainer extends Component {
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

  get safeHtmlContent() {
    return htmlSafe(this.args.data.contentHtml);
  }

  @action
  handleDismiss(_, event) {
    event.preventDefault();
    this.args.close();
    this.args.data.onDismiss();
  }
}
