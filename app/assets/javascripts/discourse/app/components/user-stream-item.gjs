import Component from "@ember/component";
import { fn } from "@ember/helper";
import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { classNameBindings, tagName } from "@ember-decorators/component";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import ExpandPost from "discourse/components/expand-post";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicStatus from "discourse/components/topic-status";
import avatar from "discourse/helpers/avatar";
import categoryLink from "discourse/helpers/category-link";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import lazyHash from "discourse/helpers/lazy-hash";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { propertyEqual } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { userPath } from "discourse/lib/url";
import { actionDescription } from "discourse/widgets/post-small-action";

@tagName("li")
@classNameBindings(
  ":user-stream-item",
  ":item", // DEPRECATED: 'item' class
  "hidden",
  "item.deleted:deleted",
  "moderatorAction"
)
export default class UserStreamItem extends Component {
  @propertyEqual("item.post_type", "site.post_types.moderator_action")
  moderatorAction;

  @actionDescription(
    "item.action_code",
    "item.created_at",
    "item.action_code_who",
    "item.action_code_path"
  )
  actionDescription;

  constructor() {
    super(...arguments);
    deprecated(
      `<UserStreamItem /> component is deprecated. Use <PostList /> or <UserStream /> component to render a post list instead.`,
      {
        since: "3.4.0.beta4",
        dropFrom: "3.5.0.beta1",
        id: "discourse.user-stream-item",
      }
    );
  }

  @computed("item.hidden")
  get hidden() {
    return (
      this.get("item.hidden") && !(this.currentUser && this.currentUser.staff)
    );
  }

  @discourseComputed("item.draft_username", "item.username")
  userUrl(draftUsername, username) {
    return userPath((draftUsername || username).toLowerCase());
  }

  <template>
    <PluginOutlet
      @name="user-stream-item-above"
      @outletArgs={{lazyHash item=@item}}
    />

    <div class="user-stream-item__header info">
      <a
        href={{this.userUrl}}
        data-user-card={{or @item.draft_username @item.username}}
        class="avatar-link"
      >
        <div class="avatar-wrapper">
          {{avatar
            @item
            imageSize="large"
            extraClasses="actor"
            ignoreTitle="true"
          }}
        </div>
      </a>

      <div class="user-stream-item__details">
        <div class="stream-topic-title">
          <TopicStatus @topic={{@item}} @disableActions={{true}} />
          <span class="title">
            {{#if @item.postUrl}}
              <a href={{@item.postUrl}}>{{replaceEmoji @item.title}}</a>
            {{else}}
              {{replaceEmoji @item.title}}
            {{/if}}
          </span>
        </div>
        <div class="category">{{categoryLink @item.category}}</div>
      </div>

      {{#if @item.draftType}}
        <span class="draft-type">{{htmlSafe @item.draftType}}</span>
      {{else}}
        <ExpandPost @item={{@item}} />
      {{/if}}

      <div class="user-stream-item__metadata">
        <span class="time">{{formatDate @item.created_at}}</span>

        {{#if @item.deleted_by}}
          <span class="delete-info">
            {{icon "trash-can"}}
            {{avatar
              @item.deleted_by
              imageSize="tiny"
              extraClasses="actor"
              ignoreTitle="true"
            }}
            {{formatDate @item.deleted_at leaveAgo="true"}}
          </span>
        {{/if}}
      </div>

      <span>
        <PluginOutlet
          @name="user-stream-item-header"
          @connectorTagName="div"
          @outletArgs={{lazyHash item=@item}}
        />
      </span>
    </div>

    {{#if this.actionDescription}}
      <p class="excerpt">{{this.actionDescription}}</p>
    {{/if}}

    <p
      data-topic-id={{@item.topic_id}}
      data-post-id={{@item.post_id}}
      data-user-id={{@item.user_id}}
      class="excerpt"
    >
      {{~#if @item.expandedExcerpt}}
        {{~htmlSafe @item.expandedExcerpt~}}
      {{else}}
        {{~htmlSafe @item.excerpt~}}
      {{/if~}}
    </p>

    {{#each @item.children as |child|}}
      {{! DEPRECATED: 'child-actions' class }}
      <div class="user-stream-item-actions child-actions">
        {{icon child.icon class="icon"}}
        {{#each child.items as |grandChild|}}
          <a
            href={{grandChild.userUrl}}
            data-user-card={{grandChild.username}}
            class="avatar-link"
          >
            <div class="avatar-wrapper">
              {{avatar
                grandChild
                imageSize="tiny"
                extraClasses="actor"
                ignoreTitle="true"
                avatarTemplatePath="acting_avatar_template"
              }}
            </div>
          </a>
          {{#if grandChild.edit_reason}}
            &mdash;
            <span class="edit-reason">{{grandChild.edit_reason}}</span>{{/if}}
        {{/each}}
      </div>
    {{/each}}

    {{#if @item.editableDraft}}
      <div class="user-stream-item-draft-actions">
        <DButton
          @action={{fn @resumeDraft @item}}
          @icon="pencil"
          @label="drafts.resume"
          class="btn-default resume-draft"
        />
        <DButton
          @action={{fn @removeDraft @item}}
          @icon="trash-can"
          @title="drafts.remove"
          class="btn-danger remove-draft"
        />
      </div>
    {{/if}}

    {{yield to="bottom"}}
  </template>
}
