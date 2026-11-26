import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBoxComponent from "discourse/select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";

@classNames("ai-concept-chooser")
@pluginApiIdentifiers("ai-concept-chooser")
@selectKitOptions({
  allowAny: false,
  autoFilterable: false,
  castInteger: true,
  clearable: true,
  filterable: true,
  filterPlaceholder: "discourse_ai.concepts.chooser_placeholder",
})
export default class AiConceptChooser extends ComboBoxComponent {
  nameProperty = "name";
  valueProperty = "id";

  #knownConcepts = new Map();

  @computed("content.[]", "selectedConcept", "selectKit.noneItem", "value")
  get selectedContent() {
    if (this.value !== null && this.value !== undefined && this.value !== "") {
      const id = Number(this.value);
      const known =
        this.#knownConcepts.get(id) ||
        (this.selectedConcept?.id === id ? this.selectedConcept : null) ||
        (this.content || []).find((item) => item.id === id);

      return this.selectKit.modifySelection(known || this.defaultItem(id, id));
    }

    return this.selectKit.noneItem;
  }

  async search(filter) {
    try {
      const data = {
        status: "non_retired",
        order: "name",
        per_page: 50,
      };
      const trimmed = (filter || "").trim();
      if (trimmed) {
        data.filter = trimmed;
      }

      const response = await ajax(
        "/admin/plugins/discourse-ai/ai-concepts.json",
        {
          data,
        }
      );

      if (this.isDestroying || this.isDestroyed) {
        return [];
      }

      const excludeId = this.excludeId ? Number(this.excludeId) : null;
      const concepts = (response.ai_concepts || []).filter(
        (concept) => concept.id !== excludeId
      );

      for (const concept of concepts) {
        this.#knownConcepts.set(concept.id, concept);
      }

      return concepts;
    } catch (error) {
      popupAjaxError(error);
      return [];
    }
  }
}
