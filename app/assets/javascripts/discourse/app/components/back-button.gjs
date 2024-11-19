import { LinkTo } from "@ember/routing";
import { or } from "truth-helpers";
import dIcon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

<template>
  <LinkTo class="btn btn-flat back-button" @route={{@route}}>
    {{dIcon "chevron-left"}}
    {{i18n (or @label "back_button")}}
  </LinkTo>
</template>
