import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class CreateSubcategory extends Component {
  @service site;

  @tracked saving = false;

  data = { name: "" };

  #formApi;

  @action
  registerFormApi(formApi) {
    this.#formApi = formApi;
  }

  @action
  submit() {
    return this.#formApi.submit();
  }

  @action
  async create({ name }) {
    this.saving = true;
    try {
      const { category } = await ajax("/categories", {
        data: { name, parent_category_id: this.args.model.id },
        type: "POST",
      });
      const createdCategory = this.site.updateCategory(category);
      this.args.closeModal();
      DiscourseURL.redirectAbsolute(createdCategory.url);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      class="create-subcategory-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "category.create_subcategory"}}
    >
      <:body>
        <p>{{i18n
            "category.create_subcategory_description"
            categoryName=@model.name
          }}</p>
        <Form
          @data={{this.data}}
          @onRegisterApi={{this.registerFormApi}}
          @onSubmit={{this.create}}
          as |form|
        >
          <form.Field
            @format="full"
            @name="name"
            @title={{i18n "category.name"}}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control autofocus="autofocus" @maxlength="50" />
          </form.Field>
        </Form>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.submit}}
          @disabled={{this.saving}}
          @label="category.create_subcategory"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
