import { action } from "@ember/object";
import { getOwner } from "discourse-common/lib/get-owner";

const SELECTOR_EDITOR_PREVIEW =
  "#reply-control .d-editor-preview-wrapper > .d-editor-preview";

export default {
  setupComponent(args, component) {
    component.setProperties({
      templatesVisible: false,
      model: getOwner(this).lookup("controller:composer").model,
    });

    this.appEvents.on("discourse-templates:show", this, "show");
    this.appEvents.on("discourse-templates:hide", this, "hide");
  },

  teardownComponent() {
    this.appEvents.off("discourse-templates:show", this, "show");
    this.appEvents.off("discourse-templates:hide", this, "hide");
  },

  shouldRender(args, component) {
    return !component.site.mobileView;
  },

  @action
  show({ onInsertTemplate }) {
    const elemEditorPreview = document.querySelector(SELECTOR_EDITOR_PREVIEW);
    if (elemEditorPreview) {
      elemEditorPreview.style.display = "none";
    }

    this.set("onInsertTemplate", onInsertTemplate);
    this.set("templatesVisible", true);
  },

  @action
  hide() {
    const elemEditorPreview = document.querySelector(SELECTOR_EDITOR_PREVIEW);
    if (elemEditorPreview) {
      elemEditorPreview.style.display = "";
    }

    this.set("templatesVisible", false);
  },
};
