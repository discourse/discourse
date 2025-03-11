import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import LinksRedirect from "discourse/components/links-redirect";
import PluginOutlet from "discourse/components/plugin-outlet";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import icon from "discourse/helpers/d-icon";
import discourseTag from "discourse/helpers/discourse-tag";
import htmlSafe from "discourse/helpers/html-safe";
import and from "truth-helpers/helpers/and";
import eq from "truth-helpers/helpers/eq";
import not from "truth-helpers/helpers/not";
import or from "truth-helpers/helpers/or";

const Revisions = <template>
  <div id="revisions" data-post-id={{@model.post_id}} class={{@hiddenClasses}}>
    {{#if @model.title_changes}}
      <div class="row">
        <h2 class="revision__title">{{htmlSafe @titleDiff}}</h2>
      </div>
    {{/if}}
    {{#if @mobileView}}
      {{#if @userChanges}}
        <div class="row">
          {{boundAvatarTemplate
            @model.user_changes.previous.avatar_template
            "small"
          }}
          {{@model.user_changes.previous.username}}
          &rarr;
          {{boundAvatarTemplate
            @model.user_changes.current.avatar_template
            "small"
          }}
          {{@model.user_changes.current.username}}
        </div>
      {{/if}}
      {{#if @model.wiki_changes}}
        <div class="row">
          {{icon
            "far-pen-to-square"
            class=(if @model.wiki_changes.current "diff-ins" "diff-del")
          }}
        </div>
      {{/if}}
      {{#if @model.archetype_changes}}
        <div class="row">
          {{icon
            (if
              (eq @model.archetype_changes.current "private_message")
              "envelope"
              "comment"
            )
          }}
        </div>
      {{/if}}
      {{#if (and @model.category_id_changes (not @model.archetype_changes))}}
        <div class="row">
          {{#if @previousCategory}}
            {{htmlSafe @previousCategory}}
          {{else}}
            {{icon "far-eye-slash" class="diff-del"}}
          {{/if}}
          &rarr;
          {{#if @currentCategory}}
            {{htmlSafe @currentCategory}}
          {{else}}
            {{icon "far-eye-slash" class="diff-ins"}}
          {{/if}}
        </div>
      {{/if}}
    {{/if}}
    {{#if @model.tags_changes}}
      <div class="row -tag-revisions">
        <span class="discourse-tags">
          {{#each @previousTagChanges as |t|}}
            {{discourseTag t.name extraClass=(if t.deleted "diff-del")}}
          {{/each}}
        </span>
        {{#if (or @mobileView (eq @viewMode "inline"))}}
          &rarr;&nbsp;
        {{/if}}
        <span class="discourse-tags">
          {{#each @currentTagChanges as |t|}}
            {{discourseTag t.name extraClass=(if t.inserted "diff-ins")}}
          {{/each}}
        </span>
      </div>
    {{/if}}
    {{#if @model.featured_link_changes}}
      <div class="row">
        {{@model.featured_link_changes.previous}}
        &rarr;
        {{@model.featured_link_changes.current}}
      </div>
    {{/if}}

    <span>
      <PluginOutlet
        @name="post-revisions"
        @connectorTagName="div"
        @outletArgs={{hash model=@model}}
      />
    </span>

    <LinksRedirect
      {{didInsert @calculateBodyDiff @bodyDiffHTML}}
      {{didUpdate @calculateBodyDiff @bodyDiffHTML}}
      class="row body-diff"
    >
      {{htmlSafe @bodyDiff}}
    </LinksRedirect>
  </div>
</template>;
export default Revisions;
