import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import IconPicker from "select-kit/components/icon-picker";
import { TOAST } from "float-kit/lib/constants";
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
    {{! template-lint-disable no-potential-path-strings }}
    <StyleguideExample @title="Toasts service">
      <StyleguideComponent @tag="default">
        <:actions>
          <DButton
            @translatedLabel="Show default toast"
            @action={{fn this.showToast "default"}}
          />
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="success">
        <:actions>
          <DButton
            @translatedLabel="Show success toast"
            @action={{fn this.showToast "success"}}
          />
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="warning">
        <:actions>
          <DButton
            @translatedLabel="Show warning toast"
            @action={{fn this.showToast "warning"}}
          />
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="info">
        <:actions>
          <DButton
            @translatedLabel="Show info toast"
            @action={{fn this.showToast "info"}}
          />
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="error">
        <:actions>
          <DButton
            @translatedLabel="Show error toast"
            @action={{fn this.showToast "error"}}
          />
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="custom component">
        <:actions>
          <DButton
            @translatedLabel="Show toast"
            @action={{this.showCustomComponentToast}}
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
            <Input @value={{this.duration}} @type="number" />
          </Row>
        {{/if}}
        <Row @name="[@options.class]">
          <Input @value={{this.class}} />
        </Row>
        <Row>
          <b>Model props for default:</b>
        </Row>
        <Row @name="[@options.data.title]">
          <Input @value={{this.title}} />
        </Row>
        <Row @name="[@options.data.message]">
          <Input @value={{this.message}} />
        </Row>
        <Row @name="[@options.data.icon]">
          <IconPicker
            @name="icon"
            @value={{this.icon}}
            @options={{hash maximum=1}}
            @onChange={{fn (mut this.icon)}}
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
