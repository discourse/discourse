import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import CategoryChooser from "select-kit/components/category-chooser";
import TagChooser from "select-kit/components/tag-chooser";
import UserChooser from "select-kit/components/user-chooser";

export default class AdminEmbeddingHostForm extends Component {
  @service router;
  @service site;
  @service store;
  @controller adminEmbedding;

  get isUpdate() {
    return this.args.host;
  }

  get header() {
    return this.isUpdate
      ? "admin.embedding.host_form.edit_header"
      : "admin.embedding.host_form.add_header";
  }

  get formData() {
    if (this.isUpdate) {
      return {
        host: this.args.host.host,
        allowed_paths: this.args.host.allowed_paths,
        category: this.args.host.category_id,
        tags: this.args.host.tags,
        user: this.args.host.user,
      };
    } else {
      return {};
    }
  }

  @action
  async save(data) {
    const host = this.args.host || this.store.createRecord("embeddable-host");

    try {
      await host.save({
        ...data,
        user: data.user?.at(0),
        category_id: data.category,
      });
      if (!this.isUpdate) {
        this.adminEmbedding.embedding.embeddable_hosts.push(host);
      }
      this.router.transitionTo("adminEmbedding");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <BackButton @route="adminEmbedding" @label="admin.embedding.back" />
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content admin-embedding-host-form">
        <AdminConfigAreaCard @heading={{this.header}}>
          <:content>
            <Form @onSubmit={{this.save}} @data={{this.formData}} as |form|>
              <form.Field
                @name="host"
                @title={{i18n "admin.embedding.host"}}
                @validation="required"
                @format="large"
                as |field|
              >
                <field.Input placeholder="example.com" />
              </form.Field>
              <form.Field
                @name="allowed_paths"
                @title={{i18n "admin.embedding.allowed_paths"}}
                @format="large"
                as |field|
              >
                <field.Input placeholder="/blog/.*" />
              </form.Field>
              <form.Field
                @name="category"
                @title={{i18n "admin.embedding.category"}}
                as |field|
              >
                <field.Custom>
                  <CategoryChooser
                    @value={{field.value}}
                    @onChange={{field.set}}
                    class="admin-embedding-host-form__category"
                  />
                </field.Custom>
              </form.Field>
              <form.Field
                @name="tags"
                @title={{i18n "admin.embedding.tags"}}
                as |field|
              >
                <field.Custom>
                  <TagChooser
                    @tags={{field.value}}
                    @everyTag={{true}}
                    @excludeSynonyms={{true}}
                    @unlimitedTagCount={{true}}
                    @onChange={{field.set}}
                    @options={{hash
                      filterPlaceholder="category.tags_placeholder"
                    }}
                    class="admin-embedding-host-form__tags"
                  />
                </field.Custom>
              </form.Field>
              <form.Field
                @name="user"
                @title={{i18n "admin.embedding.post_author"}}
                as |field|
              >
                <field.Custom>
                  <UserChooser
                    @value={{field.value}}
                    @onChange={{field.set}}
                    @options={{hash maximum=1 excludeCurrentUser=false}}
                    class="admin-embedding-host-form__post_author"
                  />
                </field.Custom>
              </form.Field>

              <form.Submit @label="admin.embedding.host_form.save" />
            </Form>
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
