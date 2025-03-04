import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import boundDate from "discourse/helpers/bound-date";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import iN from "discourse/helpers/i18n";
import and from "truth-helpers/helpers/and";
import eq from "truth-helpers/helpers/eq";
import not from "truth-helpers/helpers/not";

export default class Revision extends Component {<template><div id="revision">
  <div id="revision-details">
    {{dIcon "pencil"}}
    <LinkTo @route="user" @model={{@model.username}} class="revision-details__user">
      {{boundAvatarTemplate @model.avatar_template "small"}}
      {{#if this.siteSettings.prioritize_full_name_in_ux}}
        {{@model.acting_user_name}}
      {{else}}
        {{@model.username}}
      {{/if}}
    </LinkTo>
    <PluginOutlet @name="revision-user-details-after" @outletArgs={{hash model=@model}} />
    <span class="date">{{boundDate @model.created_at}}</span>
    {{#if @model.edit_reason}}
      <span class="edit-reason">{{@model.edit_reason}}</span>
    {{/if}}

    {{#if this.site.desktopView}}
      <span>
        {{#if @model.user_changes}}
          {{boundAvatarTemplate @model.user_changes.previous.avatar_template "small"}}
          {{@model.user_changes.previous.username}}
          &rarr;
          {{boundAvatarTemplate @model.user_changes.current.avatar_template "small"}}
          {{@model.user_changes.current.username}}
        {{/if}}

        {{#if @model.wiki_changes}}
          {{dIcon "far-pen-to-square" class=(if @model.wiki_changes.current "diff-ins" "diff-del")}}
        {{/if}}

        {{#if @model.post_type_changes}}
          {{dIcon "shield-halved" class=(if (eq @model.post_type_changes.current @site.post_types.moderator_action) "diff-del" "diff-ins")}}
        {{/if}}

        {{#if @model.archetype_changes}}
          {{dIcon (if (eq @model.archetype_changes.current "private_message") "envelope" "comment")}}
        {{/if}}

        {{#if (and @model.category_id_changes (not @model.archetype_changes))}}
          {{#if @previousCategory}}
            {{htmlSafe @previousCategory}}
          {{else}}
            {{dIcon "far-eye-slash" class="diff-del"}}
          {{/if}}
          &rarr;
          {{#if @currentCategory}}
            {{htmlSafe @currentCategory}}
          {{else}}
            {{dIcon "far-eye-slash" class="diff-ins"}}
          {{/if}}
        {{/if}}
      </span>
    {{/if}}
  </div>

  {{#if this.site.desktopView}}
    <div id="display-modes">
      <ul class="nav nav-pills">
        <li>
          <a href class={{concatClass "inline-mode" (if (eq @viewMode "inline") "active")}} {{on "click" @displayInline}} title={{iN "post.revisions.displays.inline.title"}} aria-label={{iN "post.revisions.displays.inline.title"}}>
            {{dIcon "far-square"}}
            {{iN "post.revisions.displays.inline.button"}}
          </a>
        </li>
        <li>
          <a href class={{concatClass "side-by-side-mode" (if (eq @viewMode "side_by_side") "active")}} {{on "click" @displaySideBySide}} title={{iN "post.revisions.displays.side_by_side.title"}} aria-label={{iN "post.revisions.displays.side_by_side.title"}}>
            {{dIcon "table-columns"}}
            {{iN "post.revisions.displays.side_by_side.button"}}
          </a>
        </li>
        <li>
          <a href class={{concatClass "side-by-side-markdown-mode" (if (eq @viewMode "side_by_side_markdown") "active")}} {{on "click" @displaySideBySideMarkdown}} title={{iN "post.revisions.displays.side_by_side_markdown.title"}} aria-label={{iN "post.revisions.displays.side_by_side_markdown.title"}}>
            {{dIcon "table-columns"}}
            {{iN "post.revisions.displays.side_by_side_markdown.button"}}
          </a>
        </li>
      </ul>
    </div>
  {{/if}}
</div></template>
  @service site;
  @service siteSettings;
}
