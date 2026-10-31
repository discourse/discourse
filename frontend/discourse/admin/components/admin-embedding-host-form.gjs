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
import legacyPickOne from "discourse/lib/legacy-pick-one";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import { i18n } from "discourse-i18n";

export default class AdminEmbeddingHostForm extends Component {
  @service router;
  @service siteSettings;
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
                  {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
                  {{#if this.siteSettings.enable_new_select_controls}}
                    <DSelectCategory
                      class="category-chooser admin-embedding-host-form__category"
                      @emit="ids"
                      @onChange={{field.set}}
                      @permission="create"
                      @texts={{hash ariaLabel=field.title}}
                      @value={{field.value}}
                    />
                  {{else}}
                    <CategoryChooser
                      class="admin-embedding-host-form__category"
                      @onChange={{field.set}}
                      @value={{field.value}}
                    />
                  {{/if}}
                </field.Control>
              </form.Field>
              <form.Field
                @name="tags"
                @title={{i18n "admin.embedding.tags"}}
                @type="custom"
                as |field|
              >
                <field.Control>
                  {{! TODO (select-kit-replacement-cleanup) }}
                  {{#if this.siteSettings.enable_new_select_controls}}
                    <DSelectTag
                      class="admin-embedding-host-form__tags"
                      @excludeSynonyms={{true}}
                      @ignoreRestrictions={{true}}
                      @maximum={{false}}
                      @multiple={{true}}
                      @onChange={{field.set}}
                      @texts={{hash
                        ariaLabel=field.title
                        placeholder=(i18n "category.tags_placeholder")
                      }}
                      @value={{field.value}}
                    />
                  {{else}}
                    {{! TODO (select-kit-replacement-cleanup) }}
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
                  {{/if}}
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
                  {{! TODO (select-kit-replacement-cleanup) }}
                  {{#if this.siteSettings.enable_new_select_controls}}
                    <DSelectUser
                      class="admin-embedding-host-form__post_author"
                      @clearable={{true}}
                      @describedBy={{field.describedBy}}
                      @disabled={{field.disabled}}
                      @id={{field.id}}
                      @invalid={{if field.error true false}}
                      @onChange={{legacyPickOne field.set}}
                      @texts={{hash ariaLabel=field.title}}
                      @value={{field.value}}
                    />
                  {{else}}
                    {{! TODO (select-kit-replacement-cleanup) }}
                    <UserChooser
                      class="admin-embedding-host-form__post_author"
                      @onChange={{field.set}}
                      @options={{hash maximum=1 excludeCurrentUser=false}}
                      @value={{field.value}}
                    />
                  {{/if}}
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
