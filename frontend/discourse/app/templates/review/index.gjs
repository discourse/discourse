import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import ReviewIndex from "discourse/components/reviewable/index";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DNavItem from "discourse/ui-kit/d-nav-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

<template>
  <ul class="nav nav-pills reviewable-title">
    <DNavItem @route="review.index" @label="review.view_all" />
    <DNavItem @route="review.topics" @label="review.grouped_by_topic" />
    {{#if @controller.currentUser.admin}}
      <DNavItem
        @route="review.settings"
        @label="review.settings.title"
        @icon="wrench"
      />
    {{/if}}
  </ul>
  {{#if @controller.displayUnknownReviewableTypesWarning}}
    <div class="alert alert-info unknown-reviewables">
      <span class="text">{{i18n
          "review.unknown.title"
          count=@controller.unknownReviewableTypes.length
        }}</span>

      <ul>
        {{#each @controller.unknownReviewableTypes as |reviewable|}}
          {{#if (eq reviewable.source @controller.unknownTypeSource)}}
            <li>{{i18n
                "review.unknown.reviewable_unknown_source"
                reviewableType=reviewable.type
              }}</li>
          {{else}}
            <li>{{i18n
                "review.unknown.reviewable_known_source"
                reviewableType=reviewable.type
                pluginName=reviewable.source
              }}</li>
          {{/if}}
        {{/each}}
      </ul>
      <span class="text">{{trustHTML
          (i18n
            "review.unknown.instruction"
            url="https://meta.discourse.org/t/350179"
          )
        }}</span>
      <div class="unknown-reviewables__options">
        <LinkTo @route="adminPlugins.index" class="btn">
          {{dIcon "puzzle-piece"}}
          <span>{{i18n "review.unknown.enable_plugins"}}</span>
        </LinkTo>
        <DButton
          @label="review.unknown.ignore_all"
          @icon="trash-can"
          @action={{@controller.ignoreAllUnknownTypes}}
          class="btn-default"
        />
      </div>
    </div>
  {{/if}}

  <ReviewIndex @controller={{@controller}} />
</template>
