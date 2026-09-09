import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import { MENU } from "discourse/float-kit/lib/constants";
import withEventValue from "discourse/helpers/with-event-value";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
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
  @tracked _content = trustHTML("<ul><li>Hello</li><li>World!</li></ul>");

  get content() {
    return this._content;
  }

  set content(value) {
    this._content = trustHTML(value);
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

  <template>
    <StyleguideExample @title="<Dmenu />">
      <StyleguideComponent @tag="dmenu component">
        <:sample>
          <DMenu
            @arrow={{this.arrow}}
            @content={{this.content}}
            @identifier={{this.identifier}}
            @interactive={{this.interactive}}
            @label={{this.label}}
            @maxWidth={{this.maxWidth}}
            @offset={{this.offset}}
            @triggers={{this.triggers}}
            @untriggers={{this.untriggers}}
          >
            {{this.content}}
          </DMenu>
        </:sample>
      </StyleguideComponent>

      <StyleguideComponent @tag="dmenu component">
        <:sample>
          <DMenu
            @arrow={{this.arrow}}
            @content={{this.content}}
            @identifier={{this.identifier}}
            @interactive={{this.interactive}}
            @maxWidth={{this.maxWidth}}
            @offset={{this.offset}}
            @triggers={{this.triggers}}
            @untriggers={{this.untriggers}}
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
            class="btn btn-default"
            id="menu-instance"
            type="button"
          >{{this.label}}</button>
        </:sample>
        <:actions>
          <DButton @action={{this.registerMenu}}>Register</DButton>
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="menu service">
        <:sample>
          <button
            class="btn btn-default"
            id="menu-instance-with-component"
            type="button"
          >{{this.label}}</button>
        </:sample>
        <:actions>
          <DButton @action={{this.registerMenuWithComponent}}>Register</DButton>
        </:actions>
      </StyleguideComponent>

      <Controls>
        <Row @name="Example label">
          <input
            type="text"
            value={{this.label}}
            {{on "input" (withEventValue (fn (mut this.label)))}}
          />
        </Row>
        <Row @name="[@content]">
          <input
            type="text"
            value={{this.content}}
            {{on "input" (withEventValue (fn (mut this.content)))}}
          />
        </Row>
        <Row @name="[@identifier]">
          <input
            type="text"
            value={{this.identifier}}
            {{on "input" (withEventValue (fn (mut this.identifier)))}}
          />
        </Row>
        <Row @name="[@offset]">
          <input
            type="number"
            value={{this.offset}}
            {{on "input" (withEventValue (fn (mut this.offset)))}}
          />
        </Row>
        <Row @name="[@triggers]">
          <input
            type="text"
            value={{this.triggers}}
            {{on "input" (withEventValue (fn (mut this.triggers)))}}
          />
        </Row>
        <Row @name="[@untriggers]">
          <input
            type="text"
            value={{this.untriggers}}
            {{on "input" (withEventValue (fn (mut this.untriggers)))}}
          />
        </Row>
        <Row @name="[@maxWidth]">
          <input
            type="number"
            value={{this.maxWidth}}
            {{on "input" (withEventValue (fn (mut this.maxWidth)))}}
          />
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
