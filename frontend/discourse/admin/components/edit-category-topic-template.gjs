import { buildCategoryPanel } from "discourse/admin/components/edit-category-panel";
import CategoryTopicTemplateEditor from "discourse/components/category-topic-template-editor";

export default class EditCategoryTopicTemplate extends buildCategoryPanel(
  "topic-template"
) {
  <template>
    <CategoryTopicTemplateEditor
      @category={{or this.transientData this.category}}
      @onChange={{this.form.set}}
    />
  </template>
}
