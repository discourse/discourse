import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { eq } from "truth-helpers";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import Permalink from "admin/models/permalink";

const TYPE_TO_FIELD_MAP = {
  topic: "topicId",
  post: "postId",
  category: "categoryId",
  tag: "tagName",
  user: "userId",
  external_url: "externalUrl",
};

export default class AdminFlagsForm extends Component {
  @service router;
  @service store;
  @controller adminPermalinks;

  get isUpdate() {
    return this.args.permalink;
  }

  @cached
  get formData() {
    if (this.isUpdate) {
      let permalinkType;
      let permalinkValue;
      if (!isEmpty(this.args.permalink.topic_id)) {
        permalinkType = "topic";
        permalinkValue = this.args.permalink.topic_id;
      } else if (!isEmpty(this.args.permalink.post_id)) {
        permalinkType = "post";
        permalinkValue = this.args.permalink.post_id;
      } else if (!isEmpty(this.args.permalink.category_id)) {
        permalinkType = "category";
        permalinkValue = this.args.permalink.category_id;
      } else if (!isEmpty(this.args.permalink.tag_name)) {
        permalinkType = "tag";
        permalinkValue = this.args.permalink.tag_name;
      } else if (!isEmpty(this.args.permalink.external_url)) {
        permalinkType = "external_url";
        permalinkValue = this.args.permalink.external_url;
      } else if (!isEmpty(this.args.permalink.user_id)) {
        permalinkType = "user";
        permalinkValue = this.args.permalink.user_id;
      }

      return {
        url: this.args.permalink.url,
        [TYPE_TO_FIELD_MAP[permalinkType]]: permalinkValue,
        permalinkType,
      };
    } else {
      return {
        permalinkType: "topic",
      };
    }
  }

  get header() {
    return this.isUpdate
      ? "admin.permalink.form.edit_header"
      : "admin.permalink.form.add_header";
  }

  @action
  async save(data) {
    this.isUpdate ? await this.update(data) : await this.create(data);
  }

  @bind
  async create(data) {
    try {
      const result = await this.store.createRecord("permalink").save({
        url: data.url,
        permalink_type: data.permalinkType,
        permalink_type_value: this.valueForPermalinkType(data),
      });
      this.adminPermalinks.model.unshift(Permalink.create(result.payload));
      this.router.transitionTo("adminPermalinks");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @bind
  async update(data) {
    try {
      const result = await this.store.update(
        "permalink",
        this.args.permalink.id,
        {
          url: data.url,
          permalink_type: data.permalinkType,
          permalink_type_value: this.valueForPermalinkType(data),
        }
      );
      const index = this.adminPermalinks.model.findIndex(
        (permalink) => permalink.id === this.args.permalink.id
      );
      this.adminPermalinks.model[index] = Permalink.create(result.payload);
      this.router.transitionTo("adminPermalinks");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  valueForPermalinkType(data) {
    return data[TYPE_TO_FIELD_MAP[data.permalinkType]];
  }

  <template>
    <BackButton @route="adminPermalinks" @label="admin.permalink.back" />
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content admin-permalink-form">
        <AdminConfigAreaCard @heading={{this.header}}>
          <:content>
            <Form
              @onSubmit={{this.save}}
              @data={{this.formData}}
              as |form transientData|
            >
              <form.Field
                @name="url"
                @title={{i18n "admin.permalink.form.url"}}
                @validation="required"
                @format="large"
                as |field|
              >
                <field.Input />
              </form.Field>

              <form.Field
                @name="permalinkType"
                @title={{i18n "admin.permalink.form.permalink_type"}}
                @validation="required"
                as |field|
              >
                <field.Select as |select|>
                  <select.Option @value="topic">{{i18n
                      "admin.permalink.topic_title"
                    }}</select.Option>
                  <select.Option @value="post">{{i18n
                      "admin.permalink.post_title"
                    }}</select.Option>
                  <select.Option @value="category">{{i18n
                      "admin.permalink.category_title"
                    }}</select.Option>
                  <select.Option @value="tag">{{i18n
                      "admin.permalink.tag_title"
                    }}</select.Option>
                  <select.Option @value="external_url">{{i18n
                      "admin.permalink.external_url"
                    }}</select.Option>
                  <select.Option @value="user">{{i18n
                      "admin.permalink.user_title"
                    }}</select.Option>
                </field.Select>
              </form.Field>
              {{#if (eq transientData.permalinkType "topic")}}
                <form.Field
                  @name="topicId"
                  @title={{i18n "admin.permalink.topic_id"}}
                  @format="small"
                  @validation="required"
                  as |field|
                >
                  <field.Input />
                </form.Field>
              {{/if}}
              {{#if (eq transientData.permalinkType "post")}}
                <form.Field
                  @name="postId"
                  @title={{i18n "admin.permalink.post_id"}}
                  @format="small"
                  @validation="required"
                  as |field|
                >
                  <field.Input />
                </form.Field>
              {{/if}}
              {{#if (eq transientData.permalinkType "category")}}
                <form.Field
                  @name="categoryId"
                  @title={{i18n "admin.permalink.category_id"}}
                  @format="small"
                  @validation="required"
                  as |field|
                >
                  <field.Input />
                </form.Field>
              {{/if}}
              {{#if (eq transientData.permalinkType "tag")}}
                <form.Field
                  @name="tagName"
                  @title={{i18n "admin.permalink.tag_name"}}
                  @format="small"
                  @validation="required"
                  as |field|
                >
                  <field.Input />
                </form.Field>
              {{/if}}
              {{#if (eq transientData.permalinkType "external_url")}}
                <form.Field
                  @name="externalUrl"
                  @title={{i18n "admin.permalink.external_url"}}
                  @format="large"
                  @validation="required"
                  as |field|
                >
                  <field.Input />
                </form.Field>
              {{/if}}
              {{#if (eq transientData.permalinkType "user")}}
                <form.Field
                  @name="userId"
                  @title={{i18n "admin.permalink.user_id"}}
                  @format="small"
                  @validation="required"
                  as |field|
                >
                  <field.Input />
                </form.Field>
              {{/if}}

              <form.Submit @label="admin.permalink.form.save" />
            </Form>
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
