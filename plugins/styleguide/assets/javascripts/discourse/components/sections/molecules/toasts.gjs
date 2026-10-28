import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TOAST } from "discourse/float-kit/lib/constants";
import withEventValue from "discourse/helpers/with-event-value";
import DButton from "discourse/ui-kit/d-button";
import DIconGridPicker from "discourse/ui-kit/d-icon-grid-picker";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import DummyComponent from "discourse/plugins/styleguide/discourse/components/dummy-component";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Toasts extends Component {
  @service toasts;

  @tracked title = "Title";
  @tracked message = "Message";
  @tracked duration = TOAST.options.duration;
  @tracked autoClose = TOAST.options.autoClose;
  @tracked showProgressBar = TOAST.options.showProgressBar;
  @tracked class;
  @tracked action = true;
  @tracked icon;

  @action
  showCustomComponentToast() {
    this.toasts.show({
      duration: this.duration,
      autoClose: this.autoClose,
      class: this.class,
      component: DummyComponent,
      data: {
        foo: 1,
      },
    });
  }

  @action
  showToast(theme) {
    const actions = [];

    if (this.action) {
      actions.push({
        label: "Ok",
        class: "btn-primary",
        action: (args) => {
          // eslint-disable-next-line no-alert
          alert("Closing toast:" + args.data.title);
          args.close();
        },
      });
    }

    this.toasts[theme]({
      duration: this.duration,
      autoClose: this.autoClose,
      showProgressBar: this.showProgressBar,
      class: this.class,
      data: {
        title: this.title,
        message: this.message,
        icon: this.icon,
        actions,
      },
    });
  }

  @action
  toggleAction() {
    this.action = !this.action;
  }

  @action
  toggleAutoClose() {
    this.autoClose = !this.autoClose;
  }

  @action
  toggleShowProgressBar() {
    this.showProgressBar = !this.showProgressBar;
  }

  <template>
    <StyleguideExample @title="Toasts service">
      <StyleguideComponent @tag="default">
        <:actions>
          <DButton
            @action={{fn this.showToast "default"}}
            @translatedLabel="Show default toast"
          />
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="success">
        <:actions>
          <DButton
            @action={{fn this.showToast "success"}}
            @translatedLabel="Show success toast"
          />
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="warning">
        <:actions>
          <DButton
            @action={{fn this.showToast "warning"}}
            @translatedLabel="Show warning toast"
          />
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="info">
        <:actions>
          <DButton
            @action={{fn this.showToast "info"}}
            @translatedLabel="Show info toast"
          />
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="error">
        <:actions>
          <DButton
            @action={{fn this.showToast "error"}}
            @translatedLabel="Show error toast"
          />
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="custom component">
        <:actions>
          <DButton
            @action={{this.showCustomComponentToast}}
            @translatedLabel="Show toast"
          />
        </:actions>
      </StyleguideComponent>

      <Controls>
        <Row @name="[@options.autoClose]">
          <DToggleSwitch
            @state={{this.autoClose}}
            {{on "click" this.toggleAutoClose}}
          />
        </Row>
        <Row @name="[@options.showProgressBar]">
          <DToggleSwitch
            @state={{this.showProgressBar}}
            {{on "click" this.toggleShowProgressBar}}
          />
        </Row>
        {{#if this.autoClose}}
          <Row @name="[@options.duration] ms">
            <input
              type="number"
              value={{this.duration}}
              {{on "input" (withEventValue (fn (mut this.duration)))}}
            />
          </Row>
        {{/if}}
        <Row @name="[@options.class]">
          <input
            type="text"
            value={{this.class}}
            {{on "input" (withEventValue (fn (mut this.class)))}}
          />
        </Row>
        <Row>
          <b>Model props for default:</b>
        </Row>
        <Row @name="[@options.data.title]">
          <input
            type="text"
            value={{this.title}}
            {{on "input" (withEventValue (fn (mut this.title)))}}
          />
        </Row>
        <Row @name="[@options.data.message]">
          <input
            type="text"
            value={{this.message}}
            {{on "input" (withEventValue (fn (mut this.message)))}}
          />
        </Row>
        <Row @name="[@options.data.icon]">
          <DIconGridPicker
            @onChange={{fn (mut this.icon)}}
            @value={{this.icon}}
          />
        </Row>
        <Row @name="With an action">
          <DToggleSwitch
            @state={{this.action}}
            {{on "click" this.toggleAction}}
          />
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
