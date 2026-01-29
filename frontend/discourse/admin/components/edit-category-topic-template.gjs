import Component from "@glimmer/component";
import CategoryTopicTemplateEditor from "discourse/components/category-topic-template-editor";

export default class EditCategoryTopicTemplate extends Component {
  get category() {
    return this.args.category;
  }

  get form() {
    return this.args.form;
  }

  get transientData() {
    return this.args.transientData;
  }

  get panelClass() {
    const isActive = this.args.selectedTab === "topic-template" ? "active" : "";
    return `edit-category-tab edit-category-tab-topic-template ${isActive}`;
  }

  <template>
    <div class={{this.panelClass}}>
      <CategoryTopicTemplateEditor
        @category={{this.category}}
        @form={{this.form}}
        @transientData={{this.transientData}}
      />
    </div>
  </template>
}
