/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import FilterableList from "../../components/d-templates/filterable-list";

const SELECTOR_EDITOR_PREVIEW =
  "#reply-control .d-editor-preview-wrapper > .d-editor-preview";

@classNames("d-templates")
export default class DTemplatesEditorPreview extends Component {
  static shouldRender(args, context) {
    return !context.site.mobileView;
  }

  @service appEvents;

  templatesVisible = false;
  onInsertTemplate;

  constructor() {
    super(...arguments);

    this.appEvents.on("discourse-templates:show", this, "show");
    this.appEvents.on("discourse-templates:hide", this, "hide");
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.appEvents.off("discourse-templates:show", this, "show");
    this.appEvents.off("discourse-templates:hide", this, "hide");
  }

  @action
  show({ onInsertTemplate }) {
    const elemEditorPreview = document.querySelector(SELECTOR_EDITOR_PREVIEW);
    if (elemEditorPreview) {
      elemEditorPreview.style.display = "none";
    }

    this.set("onInsertTemplate", onInsertTemplate);
    this.set("templatesVisible", true);
  }

  @action
  hide() {
    const elemEditorPreview = document.querySelector(SELECTOR_EDITOR_PREVIEW);
    if (elemEditorPreview) {
      elemEditorPreview.style.display = "";
    }

    this.set("templatesVisible", false);
  }

  <template>
    {{#if this.templatesVisible}}
      <div class="d-templates-container">
        <DButton
          @action={{this.hide}}
          @icon="xmark"
          class="modal-close close btn-flat"
        />
        <FilterableList
          @onInsertTemplate={{this.onInsertTemplate}}
          @onAfterInsertTemplate={{this.hide}}
        />
      </div>
    {{/if}}
  </template>
}
