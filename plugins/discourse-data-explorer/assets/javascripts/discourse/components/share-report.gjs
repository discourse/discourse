import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ShareReport extends Component {
  @tracked visible = false;
  element;

  get link() {
    return getURL(`/g/${this.args.group}/reports/${this.args.query.id}`);
  }

  @bind
  mouseDownHandler(e) {
    if (!this.element.contains(e.target)) {
      this.close();
    }
  }

  @bind
  keyDownHandler(e) {
    if (e.keyCode === 27) {
      this.close();
    }
  }

  @action
  registerListeners(element) {
    if (!element || this.isDestroying || this.isDestroyed) {
      return;
    }

    this.element = element;
    document.addEventListener("mousedown", this.mouseDownHandler);
    element.addEventListener("keydown", this.keyDownHandler);
  }

  @action
  unregisterListeners(element) {
    this.element = element;
    document.removeEventListener("mousedown", this.mouseDownHandler);
    element.removeEventListener("keydown", this.keyDownHandler);
  }

  @action
  focusInput(e) {
    e.select();
    e.focus();
  }

  @action
  open(e) {
    e.preventDefault();
    this.visible = true;
  }

  @action
  close() {
    this.visible = false;
  }

  <template>
    <div class="share-report">
      <a class="share-report-button" href="#" {{on "click" this.open}}>
        {{dIcon "link"}}
        {{@group}}
      </a>

      {{#if this.visible}}
        <div
          class="popup"
          {{didInsert this.registerListeners}}
          {{willDestroy this.unregisterListeners}}
        >
          <label>{{i18n "explorer.link"}} {{@group}}</label>
          <input
            type="text"
            value={{this.link}}
            {{didInsert this.focusInput}}
          />

          <DButton
            class="btn-flat close"
            @action={{this.close}}
            @aria-label="share.close"
            @icon="xmark"
            @title="share.close"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
