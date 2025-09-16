import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import TextareaTextManipulation from "discourse/lib/textarea-text-manipulation";
import { replaceVariables } from "../../lib/replace-variables";
import extractVariablesFromComposerModel from "../../lib/variables-composer";

export default class DTemplatesService extends Service {
  @service appEvents;
  @service modal;
  @service site;
  @service currentUser;
  @service dTemplatesModal;
  @service composer;

  showComposerUI() {
    const onInsertTemplate = this.#insertTemplateIntoComposer.bind(this);

    if (this.site.mobileView || !this.composer.isPreviewVisible) {
      this.#showModal(null, onInsertTemplate); // textarea must be empty when targeting the composer
    } else {
      this.#showComposerPreviewUI(onInsertTemplate);
    }
  }

  showTextAreaUI(variablesExtractor = null, textarea = document.activeElement) {
    if (!this.#isTextArea(textarea)) {
      return;
    }

    const modal = document.querySelector(".d-modal");
    const onInsertTemplate = this.#insertTemplateIntoTextArea.bind(this);
    const extractVariables = (model) => variablesExtractor?.(model);

    if (modal?.contains(textarea)) {
      if (!modal.classList.contains("d-templates")) {
        this.#showModal(textarea, (template) => {
          const modalModel = this.modal.activeModal?.opts?.model;
          onInsertTemplate(textarea, template, extractVariables(modalModel));
        });
      }
    } else {
      this.#showModal(textarea, (template) =>
        onInsertTemplate(textarea, template, extractVariables())
      );
    }
  }

  get isComposerFocused() {
    const activeElement = document.activeElement;

    const composerModel = getOwner(this).lookup("service:composer").model;
    const composerElement = document.querySelector(".d-editor");

    return composerModel && composerElement?.contains(activeElement);
  }

  get isTextAreaFocused() {
    return this.#isTextArea(document.activeElement);
  }

  #isTextArea(element) {
    return element?.nodeName === "TEXTAREA";
  }

  #showModal(textarea, onInsertTemplate) {
    this.dTemplatesModal.show({ textarea, onInsertTemplate });
  }

  #showComposerPreviewUI(onInsertTemplate) {
    this.appEvents.trigger("composer-messages:close");
    this.appEvents.trigger("composer:show-preview");
    this.appEvents.trigger("discourse-templates:show", { onInsertTemplate });
  }

  #insertTemplateIntoTextArea(textarea, template, variables) {
    template = this.#replaceTemplateVariables(
      template.title,
      template.content,
      variables
    );

    new TextareaTextManipulation(getOwner(this), { textarea }).insertBlock(
      template.content
    );
  }

  #insertTemplateIntoComposer(template) {
    const composerModel = getOwner(this).lookup("service:composer").model;
    const templateVariables = extractVariablesFromComposerModel(composerModel);

    template = this.#replaceTemplateVariables(
      template.title,
      template.content,
      templateVariables
    );

    // insert the title if blank
    if (composerModel && !composerModel.title) {
      composerModel.set("title", template.title);
    }

    // insert the content of the template in the composer
    this.appEvents.trigger("composer:insert-block", template.content);
  }

  #replaceTemplateVariables(title, content, variables = {}) {
    return replaceVariables(title, content, {
      ...variables,
      my_username: this.currentUser?.username,
      my_name: this.currentUser?.displayName,
    });
  }
}
