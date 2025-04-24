import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DMenu from "float-kit/components/d-menu";
import { MENU } from "float-kit/lib/constants";
import DummyComponent from "discourse/plugins/styleguide/discourse/components/dummy-component";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Menus extends Component {
  @service menu;

  @tracked label = "What is this?";
  @tracked triggers = MENU.options.triggers;
  @tracked untriggers = MENU.options.untriggers;
  @tracked arrow = MENU.options.arrow;
  @tracked inline = MENU.options.inline;
  @tracked interactive = MENU.options.interactive;
  @tracked maxWidth = MENU.options.maxWidth;
  @tracked identifier;
  @tracked offset = MENU.options.offset;
  @tracked _content = htmlSafe("<ul><li>Hello</li><li>World!</li></ul>");

  get content() {
    return this._content;
  }

  set content(value) {
    this._content = htmlSafe(value);
  }

  get templateCode() {
    return `<DMenu
  @label={{html-safe "${this.label}"}}
  @content={{html-safe "${this.content}"}}
/>`;
  }

  get templateCodeContent() {
    return `<DMenu @maxWidth={{100}}>
  <:trigger>
     ${this.label}
  </:trigger>
  <:content>
    ${this.content}
  </:content>
</DMenu>`;
  }

  get serviceCode() {
    return `this.menu.register(
  document.queryselector(".my-element"),
  { content: htmlSafe(${this.content}) }
);`;
  }

  get serviceCodeComponent() {
    return `this.menu.register(
  document.queryselector(".my-element"),
  { component: MyComponent, data: { foo: 1 } }
);`;
  }

  @action
  toggleArrow() {
    this.arrow = !this.arrow;
  }

  @action
  toggleInteractive() {
    this.interactive = !this.interactive;
  }

  @action
  toggleInline() {
    this.inline = !this.inline;
  }

  @action
  registerMenu() {
    this.menuInstance?.destroy();
    this.menuInstance = this.menu.register(
      document.querySelector("#menu-instance"),
      this.options
    );
  }

  @action
  registerMenuWithComponent() {
    this.menuInstanceWithComponent?.destroy();
    this.menuInstanceWithComponent = this.menu.register(
      document.querySelector("#menu-instance-with-component"),
      {
        ...this.options,
        component: DummyComponent,
        data: { foo: 1 },
      }
    );
  }

  get options() {
    return {
      offset: this.offset,
      arrow: this.arrow,
      maxWidth: this.maxWidth,
      identifier: this.identifier,
      interactive: this.interactive,
      triggers: this.triggers ?? ["click"],
      untriggers: this.untriggers ?? ["click"],
      content: this.content,
    };
  }

  <template>
    <StyleguideExample @title="<Dmenu />">
      <StyleguideComponent @tag="dmenu component">
        <:sample>
          <DMenu
            @label={{this.label}}
            @offset={{this.offset}}
            @arrow={{this.arrow}}
            @maxWidth={{this.maxWidth}}
            @identifier={{this.identifier}}
            @interactive={{this.interactive}}
            @triggers={{this.triggers}}
            @untriggers={{this.untriggers}}
            @content={{this.content}}
          >
            {{this.content}}
          </DMenu>
        </:sample>
      </StyleguideComponent>

      <StyleguideComponent @tag="dmenu component">
        <:sample>
          <DMenu
            @offset={{this.offset}}
            @arrow={{this.arrow}}
            @maxWidth={{this.maxWidth}}
            @identifier={{this.identifier}}
            @interactive={{this.interactive}}
            @triggers={{this.triggers}}
            @untriggers={{this.untriggers}}
            @content={{this.content}}
          >
            <:trigger>
              {{this.label}}
            </:trigger>
            <:content>
              {{this.content}}
            </:content>
          </DMenu>
        </:sample>
      </StyleguideComponent>

      <StyleguideComponent @tag="menu service">
        <:sample>
          <button
            type="button"
            class="btn btn-default"
            id="menu-instance"
          >{{this.label}}</button>
        </:sample>
        <:actions>
          <DButton @action={{this.registerMenu}}>Register</DButton>
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="menu service">
        <:sample>
          <button
            type="button"
            class="btn btn-default"
            id="menu-instance-with-component"
          >{{this.label}}</button>
        </:sample>
        <:actions>
          <DButton @action={{this.registerMenuWithComponent}}>Register</DButton>
        </:actions>
      </StyleguideComponent>

      <Controls>
        <Row @name="Example label">
          <Input @value={{this.label}} />
        </Row>
        <Row @name="[@content]">
          <Input @value={{this.content}} />
        </Row>
        <Row @name="[@identifier]">
          <Input @value={{this.identifier}} />
        </Row>
        <Row @name="[@offset]">
          <Input @value={{this.offset}} @type="number" />
        </Row>
        <Row @name="[@triggers]">
          <Input @value={{this.triggers}} />
        </Row>
        <Row @name="[@untriggers]">
          <Input @value={{this.untriggers}} />
        </Row>
        <Row @name="[@maxWidth]">
          <Input @value={{this.maxWidth}} @type="number" />
        </Row>
        <Row @name="[@interactive]">
          <DToggleSwitch
            @state={{this.interactive}}
            {{on "click" this.toggleInteractive}}
          />
        </Row>
        <Row @name="[@arrow]">
          <DToggleSwitch
            @state={{this.arrow}}
            {{on "click" this.toggleArrow}}
          />
        </Row>
        <Row @name="[@inline]">
          <DToggleSwitch
            @state={{this.inline}}
            {{on "click" this.toggleInline}}
          />
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
