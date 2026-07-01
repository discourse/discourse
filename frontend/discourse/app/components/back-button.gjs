import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import getUrl from "discourse/lib/get-url";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

<template>
  {{#if @href}}
    <DButton
      @href={{getUrl @href}}
      @icon="chevron-left"
      @label={{or @label "back_button"}}
      class="btn-transparent back-button"
    />
  {{else}}
    <LinkTo
      class="btn btn-transparent back-button"
      @route={{@route}}
      @models={{if @model (array @model) (array)}}
    >
      {{dIcon "chevron-left"}}
      {{i18n (or @label "back_button")}}
    </LinkTo>
  {{/if}}
</template>
