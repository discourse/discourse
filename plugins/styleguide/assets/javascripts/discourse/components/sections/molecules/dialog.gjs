import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Dialogs extends Component {
  @service dialog;

  @action
  openDialog(dialog = {}) {
    this.dialog[dialog.name](dialog.options);
  }

  @action
  didConfirm() {
    // eslint-disable-next-line no-alert
    alert("did confirm");
  }

  @action
  didCancel() {
    // eslint-disable-next-line no-alert
    alert("did cancel");
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
        </:actions>
      </StyleguideComponent>
    </StyleguideExample>
  </template>
}
