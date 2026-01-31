import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { alias, gt } from "@ember/object/computed";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { classNameBindings, classNames } from "@ember-decorators/component";
import { on as onEvent } from "@ember-decorators/object";
import AvatarFlair from "discourse/components/avatar-flair";
import CardContentsBase from "discourse/components/card-contents-base";
import DButton from "discourse/components/d-button";
import GroupMembershipButton from "discourse/components/group-membership-button";
import boundAvatar from "discourse/helpers/bound-avatar";
import routeAction from "discourse/helpers/route-action";
import { setting } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { groupPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

const maxMembersToDisplay = 10;

@classNames("no-bg", "group-card")
@classNameBindings(
  "visible:show",
  "showBadges",
  "hasCardBadgeImage",
  "isFixed:fixed",
  "groupClass"
)
export default class GroupCardContents extends CardContentsBase {
  @service composer;

  @setting("allow_profile_backgrounds") allowBackgrounds;
  @setting("enable_badges") showBadges;

  @alias("topic.postStream") postStream;
  @gt("moreMembersCount", 0) showMoreMembers;

  elementId = "group-card";
  mentionSelector = "a.mention-group";

  group = null;

  @discourseComputed("group.members.[]")
  highlightedMembers(members) {
    return members.slice(0, maxMembersToDisplay);
  }

  @discourseComputed("group.user_count", "group.members.[]")
  moreMembersCount(memberCount) {
    return Math.max(memberCount - maxMembersToDisplay, 0);
  }

  @discourseComputed("group.name")
  groupClass(name) {
    return name ? `group-card-${name}` : "";
  }

  @discourseComputed("group")
  groupPath(group) {
    return groupPath(group.name);
  }

  @onEvent("didInsertElement")
  _inserted() {
    this.appEvents.on("dom:clean", this, this._close);
  }

  @onEvent("didDestroyElement")
  _destroyed() {
    this.appEvents.off("dom:clean", this, this._close);
  }

  async _showCallback(username) {
    this.setProperties({ visible: true, loading: true });

    try {
      const group = await this.store.find("group", username);
      this.setProperties({ group });

      if (!group.flair_url && !group.flair_bg_color) {
        group.set("flair_url", "users");
      }

      if (group.can_see_members && group.members.length < maxMembersToDisplay) {
        return group.reloadMembers({ limit: maxMembersToDisplay }, true);
      }
    } catch {
      this._close();
    } finally {
      this.set("loading", null);
    }
  }

  _close() {
    this.set("group", null);

    super._close(...arguments);
  }

  @action
  close(event) {
    event?.preventDefault();
    this._close();
  }

  @action
  handleShowGroup(event) {
    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    // Invokes `showGroup` argument. Convert to `this.args.showGroup` when
    // refactoring this to a glimmer component.
    this.showGroup(this.group);
    this._close();
  }

  @action
  cancelFilter() {
    this.postStream.cancelFilter();
    this.postStream.refresh();
    this._close();
  }

  @action
  messageGroup() {
    this.composer.openNewMessage({
      recipients: this.get("group.name"),
      hasGroups: true,
    });
  }

  <template>
    {{#if this.visible}}
      <div class="card-content">
        {{#if this.loading}}
          <div class="card-row first-row">
            <div class="group-card-avatar">
              <div
                class="card-avatar-placeholder animated-placeholder placeholder-animation"
              ></div>
            </div>
          </div>

          <div class="card-row second-row">
            <div class="animated-placeholder placeholder-animation"></div>
          </div>
        {{else}}
          <div class="card-row first-row">
            <div class="group-card-avatar">
              <a
                {{on "click" this.handleShowGroup}}
                href={{this.groupPath}}
                class="card-huge-avatar"
              >
                <AvatarFlair
                  @flairName={{this.group.name}}
                  @flairUrl={{this.group.flair_url}}
                  @flairBgColor={{this.group.flair_bg_color}}
                  @flairColor={{this.group.flair_color}}
                />
              </a>
            </div>
            <div class="names">
              <span>
                <div class="names__primary {{this.group.name}}">
                  <a
                    {{on "click" this.handleShowGroup}}
                    href={{this.groupPath}}
                    class="group-page-link"
                  >{{this.group.name}}</a>
                </div>
                {{#if this.group.full_name}}
                  <div class="names__secondary full-name">
                    {{this.group.full_name}}
                  </div>
                {{else}}
                  <div
                    class="names__secondary username"
                  >{{this.group.name}}</div>
                {{/if}}
              </span>
            </div>
            <ul class="usercard-controls group-details-button">
              <li>
                <GroupMembershipButton
                  @model={{this.group}}
                  @showLogin={{routeAction "showLogin"}}
                />
              </li>
              {{#if this.group.messageable}}
                <li>
                  <DButton
                    @action={{this.messageGroup}}
                    @icon="envelope"
                    @label="groups.message"
                    class="btn-primary group-message-button inline"
                  />
                </li>
              {{/if}}
            </ul>
          </div>

          {{#if this.group.bio_excerpt}}
            <div class="card-row second-row">
              <div class="bio">
                {{htmlSafe this.group.bio_excerpt}}
              </div>
            </div>
          {{/if}}

          {{#if this.group.members}}
            <div class="card-row third-row">
              <div class="members metadata">
                {{#each this.highlightedMembers as |user|}}
                  <a
                    {{on "click" this.close}}
                    href={{user.path}}
                    class="card-tiny-avatar"
                  >{{boundAvatar user "tiny"}}</a>
                {{/each}}
                {{#if this.showMoreMembers}}
                  <a
                    {{on "click" this.handleShowGroup}}
                    href={{this.groupPath}}
                    class="more-members-link"
                  >
                    <span class="more-members-count">+{{this.moreMembersCount}}
                      {{i18n "more"}}</span>
                  </a>
                {{/if}}
              </div>
            </div>
          {{/if}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
