import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

<template>
  <div class="tag-group-content">
    <h3>
      {{#if @controller.model}}
        {{i18n "tagging.groups.about_heading"}}
      {{else}}
        {{i18n "tagging.groups.about_heading_empty"}}
      {{/if}}
    </h3>
    <section class="tag-groups-about">
      <p>{{i18n "tagging.groups.about_description"}}</p>
    </section>
    <section>
      {{#unless @controller.model}}
        <LinkTo @route="tagGroups.new" class="btn btn-primary">
          {{icon "plus"}}
          {{i18n "tagging.groups.new"}}
        </LinkTo>
      {{/unless}}
    </section>
  </div>
</template>
