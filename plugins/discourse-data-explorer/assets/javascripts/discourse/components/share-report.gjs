import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
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
      <a href="#" {{on "click" this.open}} class="share-report-button">
        {{icon "link"}}
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
            @action={{this.close}}
            @icon="xmark"
            @aria-label="share.close"
            @title="share.close"
            class="btn-flat close"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
