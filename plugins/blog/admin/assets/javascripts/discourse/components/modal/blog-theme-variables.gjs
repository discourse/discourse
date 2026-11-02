import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DModal from "discourse/ui-kit/d-modal";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import { i18n } from "discourse-i18n";

export default class BlogThemeVariables extends Component {
  get editor() {
    return this.args.model.editor;
  }

  @action
  insert(variable) {
    this.editor.insertVariable(variable);
    this.args.closeModal();
  }

  <template>
    <DModal
      class="blog-theme-variables"
      @closeModal={{@closeModal}}
      @title={{i18n "blog.admin.variable_reference"}}
    >
      <:body>
        <p class="blog-theme-variables__hint">{{i18n
            "blog.admin.insert_hint"
          }}</p>
        <div class="blog-theme-variables__controls">
          <DFilterInput
            aria-label={{i18n "blog.admin.find_variable"}}
            placeholder={{i18n "blog.admin.find_variable"}}
            @filterAction={{this.editor.filterVariables}}
            @value={{this.editor.variableQuery}}
            {{on "keydown" this.editor.preventSearchSubmit}}
          />
          <DNativeSelect
            aria-label={{i18n "blog.admin.sample_article"}}
            @includeNone={{false}}
            @onChange={{this.editor.selectArticle}}
            @value={{this.editor.selectedArticle}}
            as |select|
          >{{#each this.editor.articleOptions as |article|}}<select.Option
                @value={{article.id}}
              >{{article.title}}</select.Option>{{/each}}</DNativeSelect>
        </div>
        <ul class="blog-theme-variables__list">
          {{#each this.editor.variables as |variable|}}
            <li
              class="blog-theme-variables__item"
              data-variable={{variable.path}}
            >
              <div class="blog-theme-variables__header">
                <code
                  class="blog-theme-variables__path"
                >{{variable.path}}</code>
                <span
                  class="blog-theme-variables__type"
                >{{variable.type}}</span>
                <DButton
                  class="btn-default btn-small blog-theme-variables__insert"
                  @action={{fn this.insert variable}}
                  @label="blog.admin.insert"
                />
              </div>
              <pre
                class="blog-theme-variables__example"
              >{{variable.example}}</pre>
            </li>
          {{else}}
            <li class="blog-theme-variables__empty">{{i18n
                "blog.admin.no_variables"
              }}</li>
          {{/each}}
        </ul>
      </:body>
      <:footer>
        <DButton @action={{@closeModal}} @label="close" />
      </:footer>
    </DModal>
  </template>
}
