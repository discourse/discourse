import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { i18n } from "discourse-i18n";

export default class AdminEmbeddingHostForm extends Component {
  @service router;
  @service store;
  @controller adminEmbedding;

  get isEditing() {
    return this.args.host;
  }

  get header() {
    return this.isEditing
      ? "admin.embedding.host_form.edit_header"
      : "admin.embedding.host_form.add_header";
  }

  get formData() {
    if (!this.isEditing) {
      return {};
    }

    return {
      host: this.args.host.host,
      allowed_paths: this.args.host.allowed_paths,
      category: this.args.host.category_id,
      tags: this.args.host.tags,
      user: isEmpty(this.args.host.user) ? null : [this.args.host.user],
    };
  }

  @action
  async save(data) {
    const host = this.args.host || this.store.createRecord("embeddable-host");

    try {
      await host.save({
        ...data,
        user: data.user?.at(0),
        category_id: data.category,
        tags: data.tags?.map((t) => t.id),
      });
      if (!this.isEditing) {
        this.adminEmbedding.embedding.embeddable_hosts.push(host);
      }
      this.router.transitionTo("adminEmbedding");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <BackButton @label="admin.embedding.back" @route="adminEmbedding" />
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content admin-embedding-host-form">
        <AdminConfigAreaCard @heading={{this.header}}>
          <:content>
            <Form @data={{this.formData}} @onSubmit={{this.save}} as |form|>
              <form.Field
                @format="large"
                @name="host"
                @title={{i18n "admin.embedding.host"}}
                @type="input"
                @validation="required"
                as |field|
              >
                <field.Control placeholder="example.com" />
              </form.Field>
              <form.Field
                @format="large"
                @name="allowed_paths"
                @title={{i18n "admin.embedding.allowed_paths"}}
                @type="input"
                as |field|
              >
                <field.Control placeholder="/blog/.*" />
              </form.Field>
              <form.Field
                @name="category"
                @title={{i18n "admin.embedding.category"}}
                @type="custom"
                as |field|
              >
                <field.Control>
                  <CategoryChooser
                    class="admin-embedding-host-form__category"
                    @onChange={{field.set}}
                    @value={{field.value}}
                  />
                </field.Control>
              </form.Field>
              <form.Field
                @name="tags"
                @title={{i18n "admin.embedding.tags"}}
                @type="custom"
                as |field|
              >
                <field.Control>
                  <TagChooser
                    class="admin-embedding-host-form__tags"
                    @everyTag={{true}}
                    @excludeSynonyms={{true}}
                    @onChange={{field.set}}
                    @options={{hash
                      filterPlaceholder="category.tags_placeholder"
                    }}
                    @tags={{field.value}}
                    @unlimitedTagCount={{true}}
                  />
                </field.Control>
              </form.Field>
              <form.Field
                @description={{i18n "admin.embedding.post_author_description"}}
                @name="user"
                @title={{i18n "admin.embedding.post_author"}}
                @type="custom"
                as |field|
              >
                <field.Control>
                  <UserChooser
                    class="admin-embedding-host-form__post_author"
                    @onChange={{field.set}}
                    @options={{hash maximum=1 excludeCurrentUser=false}}
                    @value={{field.value}}
                  />
                </field.Control>
              </form.Field>

              <form.Submit @label="admin.embedding.host_form.save" />
            </Form>
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
