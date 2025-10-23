/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import EmberObject from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, eq, not, or } from "truth-helpers";
import LinksRedirect from "discourse/components/links-redirect";
import PluginOutlet from "discourse/components/plugin-outlet";
import Avatar from "discourse/helpers/bound-avatar-template";
import icon from "discourse/helpers/d-icon";
import discourseTags from "discourse/helpers/discourse-tags";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

function tagClasses(tagChanges, state, className) {
  return (tagChanges || []).reduce((classMap, tagChange) => {
    if (tagChange[state]) {
      classMap[tagChange.name] = className;
    }
    return classMap;
  }, {});
}

export default class Revisions extends Component {
  @service languageNameLookup;

  get fakePreviousTagsTopic() {
    // discourseTags expects a topic structure
    return EmberObject.create({
      tags: (this.get("previousTagChanges") || []).map((tag) => tag.name),
    });
  }

  get previousTagClassesMap() {
    return tagClasses(this.get("previousTagChanges"), "deleted", "diff-del");
  }

  get fakeCurrentTagsTopic() {
    return EmberObject.create({
      tags: (this.get("currentTagChanges") || []).map((tag) => tag.name),
    });
  }

  get currentTagClassesMap() {
    return tagClasses(this.get("currentTagChanges"), "inserted", "diff-ins");
  }

  get previousLocale() {
    const locale = this.get("model.locale_changes.previous");
    const language = this.languageNameLookup.getLanguageName(locale);
    return language || i18n("post.revisions.locale.no_locale_set");
  }

  get currentLocale() {
    const locale = this.get("model.locale_changes.current");
    const language = this.languageNameLookup.getLanguageName(locale);
    return language || i18n("post.revisions.locale.locale_removed");
  }

  <template>
    <div
      id="revisions"
      data-post-id={{@model.post_id}}
      class={{@hiddenClasses}}
    >
      {{#if @model.locale_changes}}
        <div class="row revision__locale">
          <div class="revision-content">
            <div class={{if @model.locale_changes.previous "diff-del"}}>
              {{icon "globe"}}
              {{this.previousLocale}}
            </div>
          </div>

          {{#if (or @mobileView (eq @viewMode "inline"))}}
            &rarr;&nbsp;
          {{/if}}

          <div class="revision-content">
            <div class={{if @model.locale_changes.current "diff-ins"}}>
              {{icon "globe"}}
              {{this.currentLocale}}
            </div>
          </div>
        </div>
      {{/if}}
      {{#if @model.title_changes}}
        <div class="row">
          <h2 class="revision__title">{{htmlSafe @titleDiff}}</h2>
        </div>
      {{/if}}
      {{#if @mobileView}}
        {{#if @userChanges}}
          <div class="row">
            {{Avatar @model.user_changes.previous.avatar_template "small"}}
            {{@model.user_changes.previous.username}}
            &rarr;
            {{Avatar @model.user_changes.current.avatar_template "small"}}
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
          <span class="tag-revision__wrapper">
            {{discourseTags
              this.fakePreviousTagsTopic
              tagClasses=this.previousTagClassesMap
            }}
          </span>

          {{#if (or @mobileView (eq @viewMode "inline"))}}
            &rarr;&nbsp;
          {{/if}}

          <span class="tag-revision__wrapper">
            {{discourseTags
              this.fakeCurrentTagsTopic
              tagClasses=this.currentTagClassesMap
            }}
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
          @outletArgs={{lazyHash model=@model}}
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
  </template>
}
