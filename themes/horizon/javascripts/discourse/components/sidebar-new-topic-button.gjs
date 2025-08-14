import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { gt, not } from "truth-helpers";
import CreateTopicButton from "discourse/components/create-topic-button";

export default class SidebarNewTopicButton extends Component {
  @service composer;
  @service currentUser;
  @service siteSettings;
  @service router;
  @service header;
  @service appEvents;

  @tracked category;
  @tracked tag;

  get shouldRender() {
    return this.currentUser && !this.router.currentRouteName.includes("admin");
  }

  get canCreateTopic() {
    return this.currentUser?.can_create_topic;
  }

  get draftCount() {
    return this.currentUser?.get("draft_count");
  }

  get createTopicTargetCategory() {
    if (this.category?.canCreateTopic) {
      return this.category;
    }

    if (this.siteSettings.default_subcategory_on_read_only_category) {
      return this.category?.subcategoryWithCreateTopicPermission;
    }
  }

  get tagRestricted() {
    return this.tag?.staff;
  }

  get createTopicDisabled() {
    return (
      (this.category && !this.createTopicTargetCategory) ||
      (this.tagRestricted && !this.currentUser.staff)
    );
  }

  get categoryReadOnlyBanner() {
    if (this.category && this.currentUser && this.createTopicDisabled) {
      return this.category.read_only_banner;
    }
  }

  get createTopicClass() {
    const baseClasses = "btn-default sidebar-new-topic-button";
    return this.categoryReadOnlyBanner
      ? `${baseClasses} disabled`
      : baseClasses;
  }

  @action
  createNewTopic() {
    this.composer.openNewTopic({ category: this.category, tags: this.tag?.id });
  }

  @action
  getCategoryAndTag() {
    this.category = this.router.currentRoute.attributes?.category || null;
    this.tag = this.router.currentRoute.attributes?.tag || null;
  }

  @action
  watchForComposer() {
    // this covers opening drafts from the hamburger menu
    this.appEvents.on("composer:will-open", this, this.closeHamburger);
  }

  @action
  stopWatchingForComposer() {
    this.appEvents.off("composer:will-open", this, this.closeHamburger);
  }

  @action
  closeHamburger() {
    this.header.hamburgerVisible = false;
  }

  <template>
    {{#if this.shouldRender}}
      <div
        class="sidebar-new-topic-button__wrapper"
        {{didInsert this.getCategoryAndTag}}
        {{didUpdate this.getCategoryAndTag this.router.currentRoute}}
        {{didInsert this.watchForComposer}}
        {{willDestroy this.stopWatchingForComposer}}
      >
        <CreateTopicButton
          @canCreateTopic={{this.canCreateTopic}}
          @action={{this.createNewTopic}}
          @disabled={{this.createTopicDisabled}}
          @label="topic.create"
          @btnClass={{this.createTopicClass}}
          @canCreateTopicOnTag={{not this.tagRestricted}}
          @showDrafts={{gt this.draftCount 0}}
        />
      </div>
    {{/if}}
  </template>
}
