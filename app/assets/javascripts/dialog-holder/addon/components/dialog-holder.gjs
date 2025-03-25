import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import A11yDialog from "a11y-dialog";
import { modifier } from "ember-modifier";
import { notEq, or } from "truth-helpers";
import DButton from "discourse/components/d-button";

export default class DialogHolder extends Component {
  @service dialog;

  setupDialog = modifier((element) => {
    const dialogInstance = new A11yDialog(element);
    dialogInstance.show();

    dialogInstance.on("hide", () => {
      this.dialog.hide();
    });

    () => {
      dialogInstance.hide();
      dialogInstance.destroy();
    };
  });

  @action
  async handleButtonAction(btn) {
    if (typeof btn.action === "function") {
      await btn.action();
    }

    this.dialog.cancel();
  }

  <template>
    {{#if this.dialog.show}}
      <div
        aria-labelledby={{this.dialog.titleElementId}}
        id="dialog-holder"
        aria-hidden="true"
        class="dialog-container {{this.dialog.class}}"
        {{this.setupDialog}}
      >
        <div class="dialog-overlay" data-a11y-dialog-hide></div>

        {{#if this.dialog.type}}
          <div class="dialog-content" role="document">
            {{#if this.dialog.title}}
              <div class="dialog-header">
                <h3 id={{this.dialog.titleElementId}}>{{this.dialog.title}}</h3>
                <DButton
                  @action={{this.dialog.cancel}}
                  @title="modal.close"
                  @icon="xmark"
                  class="btn-flat dialog-close close"
                />
              </div>
            {{/if}}

            {{#if (or this.dialog.message this.dialog.bodyComponent)}}
              <div class="dialog-body">
                {{#if this.dialog.bodyComponent}}
                  <this.dialog.bodyComponent
                    @model={{this.dialog.bodyComponentModel}}
                  />
                {{else if this.dialog.message}}
                  <p>{{htmlSafe this.dialog.message}}</p>
                {{/if}}
              </div>
            {{/if}}

            {{#if (notEq this.dialog.type "notice")}}
              <div class="dialog-footer">
                {{#each this.dialog.buttons as |button|}}
                  <DButton
                    @action={{fn this.handleButtonAction button}}
                    @translatedLabel={{button.label}}
                    @icon={{button.icon}}
                    class={{button.class}}
                  />
                {{else}}
                  <DButton
                    @action={{this.dialog.didConfirmWrapped}}
                    @icon={{this.dialog.confirmButtonIcon}}
                    @label={{this.dialog.confirmButtonLabel}}
                    @disabled={{this.dialog.confirmButtonDisabled}}
                    class={{this.dialog.confirmButtonClass}}
                  />
                  {{#if this.dialog.shouldDisplayCancel}}
                    <DButton
                      @action={{this.dialog.cancel}}
                      @label={{this.dialog.cancelButtonLabel}}
                      class={{this.dialog.cancelButtonClass}}
                    />
                  {{/if}}
                {{/each}}
              </div>
            {{/if}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
