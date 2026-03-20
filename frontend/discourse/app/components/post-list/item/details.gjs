import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicStatus from "discourse/components/topic-status";
import lazyHash from "discourse/helpers/lazy-hash";
import getURL from "discourse/lib/get-url";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class PostListItemDetails extends Component {
  get url() {
    return this.args.urlPath
      ? this.args.post[this.args.urlPath]
      : this.args.post.url;
  }

  get showUserInfo() {
    if (this.args.showUserInfo !== undefined) {
      return this.args.showUserInfo && this.args.user;
    }

    return this.args.user;
  }

  get topicTitle() {
    return this.args.titlePath
      ? this.args.titlePath === "titleHtml" ||
        this.args.titlePath === "topic_html_title"
        ? trustHTML(this.args.post[this.args.titlePath])
        : this.args.post[this.args.titlePath]
      : this.args.post.title;
  }

  get draftTitle() {
    return this.args.post.title ?? this.args.post.data.title;
  }

  get titleAriaLabel() {
    if (this.args.titleAriaLabel) {
      return this.args.titleAriaLabel;
    }

    if (this.args.post.post_number && this.topicTitle) {
      return i18n("post_list.aria_post_number", {
        title: this.topicTitle,
        postNumber: this.args.post.post_number,
      });
    }
  }

  get posterName() {
    if (prioritizeNameInUx(this.args.user.name)) {
      return this.args.user.name;
    }
    return this.args.user.username;
  }

  <template>
    <div class="post-list-item__details">
      <div class="stream-topic-title">
        <TopicStatus @topic={{@post}} @disableActions={{true}} />
        <span class="title">
          {{#if this.url}}
            <a
              href={{getURL this.url}}
              aria-label={{this.titleAriaLabel}}
            >{{this.topicTitle}}</a>
          {{else if @isDraft}}
            <DButton
              @action={{fn @resumeDraft @post}}
              class="btn-transparent draft-title"
            >
              {{or this.draftTitle (i18n "drafts.dropdown.untitled")}}
            </DButton>
          {{else}}
            {{this.topicTitle}}
          {{/if}}
        </span>
      </div>

      <div class="post-list-item__metadata">
        {{#if @post.category}}
          <span class="category stream-post-category">
            {{dCategoryLink @post.category}}
          </span>
        {{/if}}

        <span class="time">
          {{dFormatDate @post.created_at leaveAgo="true"}}
        </span>

        {{#if @post.deleted_by}}
          <span class="delete-info">
            {{dIcon "trash-can"}}
            {{dAvatar
              @post.deleted_by
              imageSize="tiny"
              extraClasses="actor"
              ignoreTitle="true"
            }}
            {{dFormatDate @item.deleted_at leaveAgo="true"}}
          </span>
        {{/if}}
      </div>

      {{#if this.showUserInfo}}
        <div class="post-member-info names">
          <span class="name">{{this.posterName}}</span>

          {{#if @user.title}}
            <span class="user-title">{{@user.user_title}}</span>
          {{/if}}

          <PluginOutlet
            @name="post-list-additional-member-info"
            @outletArgs={{lazyHash user=@user post=@post}}
          />

          {{!
            Deprecated Outlet:
            Please use: "post-list-additional-member-info" instead
          }}
          <PluginOutlet
            @name="group-post-additional-member-info"
            @outletArgs={{lazyHash user=@user}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
