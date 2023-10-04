import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import DummyComponent from "discourse/plugins/styleguide/discourse/components/dummy-component";
import { htmlSafe } from "@ember/template";
import { MENU } from "float-kit/lib/constants";

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
}
