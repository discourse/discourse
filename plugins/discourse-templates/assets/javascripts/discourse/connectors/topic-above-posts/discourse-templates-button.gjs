import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const TEMPLATE_OPTIONS_START_REGEX = /^\s*<!--\s*discourse-template\s*/i;
const TEMPLATE_OPTIONS_BODY_SEPARATOR_REGEX = /^([ \t]*\r?\n){1,2}/;
const TEMPLATE_OPTIONS_MAX_LENGTH = 500;

export default class DiscourseTemplatesButton extends Component {
  static shouldRender(outletArgs, helper) {
    return outletArgs.model.is_template && helper.currentUser?.can_create_topic;
  }

  @service composer;

  @tracked copyConfirm = false;

  async fetchRaw() {
    const topic = this.args.outletArgs.model;
    return await ajax(`/raw/${topic.id}/1`, { dataType: "text" });
  }

  parseTemplateOptions(raw) {
    const header = raw.slice(0, TEMPLATE_OPTIONS_MAX_LENGTH);
    const startMatch = header.match(TEMPLATE_OPTIONS_START_REGEX);

    if (!startMatch) {
      return { body: raw };
    }

    const headerEnd = header.indexOf("-->", startMatch[0].length);

    if (headerEnd === -1) {
      return { body: raw };
    }

    const options = {};
    raw
      .slice(startMatch[0].length, headerEnd)
      .split("\n")
      .forEach((line) => {
        const [, key, value] = line.match(/^\s*([\w-]+)\s*:\s*(.*?)\s*$/) || [];

        if (key && value) {
          options[key] = value;
        }
      });

    return {
      body: raw
        .slice(headerEnd + 3)
        .replace(TEMPLATE_OPTIONS_BODY_SEPARATOR_REGEX, ""),
      categorySlug: options.category,
      tags: options.tags
        ?.split(",")
        .map((tag) => tag.trim())
        .filter(Boolean)
        .join(","),
    };
  }

  async findCategory(categorySlug) {
    if (!categorySlug) {
      return null;
    }

    const slugPath = categorySlug.split(/[/:]/).filter(Boolean);

    let category = Category.findBySlugPath(slugPath);

    if (!category?.canCreateTopic) {
      category = await Category.asyncFindBySlugPath(slugPath.join("/")).catch(
        () => null
      );
    }

    return category?.canCreateTopic ? category : null;
  }

  @action
  async createNewTopic() {
    const template = this.parseTemplateOptions(await this.fetchRaw());
    const category = await this.findCategory(template.categorySlug);

    this.composer.openNewTopic({
      body: template.body,
      category,
      tags: template.tags,
    });
  }

  @action
  async copy() {
    const text = await this.fetchRaw();
    navigator.clipboard.writeText(text);
    this.copyConfirm = true;
    discourseDebounce(this.resetCopyButton, 2000);
  }

  @action
  resetCopyButton() {
    this.copyConfirm = false;
  }

  <template>
    <div class="template-topic-controls">
      <DButton
        @icon={{if this.copyConfirm "check" "copy"}}
        @action={{this.copy}}
        @label="templates.copy"
        class={{dConcatClass
          "btn-default"
          "template-copy"
          (if this.copyConfirm "ok")
        }}
      />
      <DButton
        @action={{this.createNewTopic}}
        @label="templates.new_topic"
        @icon="plus"
        class="btn-default template-new-topic"
      />
    </div>
  </template>
}
