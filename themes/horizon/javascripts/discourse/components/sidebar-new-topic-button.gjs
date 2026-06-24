import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import CreateTopicButton from "discourse/components/create-topic-button";
import bodyClass from "discourse/helpers/body-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import { gt } from "discourse/truth-helpers";

export default class SidebarNewTopicButton extends Component {
  @service composer;
  @service currentUser;
  @service siteSettings;
  @service site;
  @service router;
  @service header;
  @service appEvents;
  @controller application;

  @tracked category;
  @tracked tag;

  get shouldRender() {
    return (
      this.currentUser &&
      !this.router.currentURL.startsWith("/admin") &&
      this.application.sidebarEnabled
    );
  }

  get canCreateTopic() {
    return this.currentUser?.can_create_topic;
  }

  get draftCount() {
    return this.currentUser?.get("draft_count");
  }

  get createTopicLabel() {
    const defaultKey = "topic.create";
    let value = defaultKey;

    if (
      this.site.shared_drafts_category_id &&
      this.category?.id === this.site.shared_drafts_category_id
    ) {
      value = "topic.create_shared_draft";
    }

    return applyValueTransformer("create-topic-label", value, {
      site: this.site,
      defaultKey,
      category: this.category,
      currentUser: this.currentUser,
    });
  }

  get createTopicIcon() {
    const defaultIcon = "far-pen-to-square";

    return applyValueTransformer("create-topic-icon", defaultIcon, {
      site: this.site,
      defaultIcon,
      category: this.category,
      currentUser: this.currentUser,
    });
  }

  get createTopicTargetCategory() {
    let subcategory;

    if (
      !this.category?.canCreateTopic &&
      this.siteSettings.default_subcategory_on_read_only_category
    ) {
      subcategory = this.category?.subcategoryWithCreateTopicPermission;
    }

    return subcategory ?? this.category;
  }

  @action
  createNewTopic() {
    this.composer.openNewTopic({
      category: this.createTopicTargetCategory,
      tags: this.tag?.name,
    });
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
      {{bodyClass "horizon-new-topic-button-enabled"}}
      <CreateTopicButton
        {{didInsert this.getCategoryAndTag}}
        {{didUpdate this.getCategoryAndTag this.router.currentRoute}}
        {{didInsert this.watchForComposer}}
        {{willDestroy this.stopWatchingForComposer}}
        @canCreateTopic={{this.canCreateTopic}}
        @action={{this.createNewTopic}}
        @label={{this.createTopicLabel}}
        @icon={{this.createTopicIcon}}
        @btnClass="sidebar-new-topic-button"
        @btnTypeClass="btn-primary"
        @showDrafts={{gt this.draftCount 0}}
        class="sidebar-new-topic-button__wrapper"
      />
    {{/if}}
  </template>
}
