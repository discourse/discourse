import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Dialogs extends Component {
  @service dialog;

  @tracked alertOutput = "";
  @tracked deleteConfirmOutput = "";
  @tracked noticeOutput = "";
  @tracked confirmOutput = "";
  @tracked yesNoConfirmOutput = "";

  @action
  async openDialog(dialog = {}) {
    this[`${dialog.name}Output`] = "";
    const confirmed = await this.dialog[dialog.name](dialog.options);
    this[`${dialog.name}Output`] = `Confirmed: ${confirmed}`;
  }

  <template>
    <StyleguideExample @title="Dialog service">
      <StyleguideComponent @tag="alert">
        <:actions>
          <DButton
            @translatedLabel="Trigger"
            @action={{fn
              this.openDialog
              (hash
                name="alert"
                options=(hash
                  message="message"
                  title="title"
                  didConfirm=this.didConfirm
                  didCancel=this.didCancel
                )
              )
            }}
          />

          <span>&nbsp;{{this.alertOutput}}</span>
        </:actions>
      </StyleguideComponent>
      <StyleguideComponent @tag="notice">
        <:actions>
          <DButton
            @translatedLabel="Trigger"
            @action={{fn
              this.openDialog
              (hash name="notice" options="message")
            }}
          />
          <span>&nbsp;{{this.noticeOutput}}</span>
        </:actions>
      </StyleguideComponent>
      <StyleguideComponent @tag="yesNoConfirm">
        <:actions>
          <DButton
            @translatedLabel="Trigger"
            @action={{fn
              this.openDialog
              (hash
                name="yesNoConfirm"
                options=(hash
                  message="message"
                  title="title"
                  didConfirm=this.didConfirm
                  didCancel=this.didCancel
                )
              )
            }}
          />
          <span>&nbsp;{{this.yesNoConfirmOutput}}</span>
        </:actions>
      </StyleguideComponent>
      <StyleguideComponent @tag="deleteConfirm">
        <:actions>
          <DButton
            @translatedLabel="Trigger"
            @action={{fn
              this.openDialog
              (hash
                name="deleteConfirm"
                options=(hash
                  message="message"
                  title="title"
                  didConfirm=this.didConfirm
                  didCancel=this.didCancel
                )
              )
            }}
          />
          <span>&nbsp;{{this.deleteConfirmOutput}}</span>
        </:actions>
      </StyleguideComponent>
      <StyleguideComponent @tag="confirm">
        <:actions>
          <DButton
            @translatedLabel="Trigger"
            @action={{fn
              this.openDialog
              (hash
                name="confirm"
                options=(hash
                  message="message"
                  title="title"
                  didConfirm=this.didConfirm
                  didCancel=this.didCancel
                )
              )
            }}
          />
          <span>&nbsp;{{this.confirmOutput}}</span>
        </:actions>
      </StyleguideComponent>
    </StyleguideExample>
  </template>
}
