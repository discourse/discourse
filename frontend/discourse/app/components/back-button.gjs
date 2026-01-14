import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

<template>
  <LinkTo class="btn btn-flat back-button" @route={{@route}}>
    {{icon "chevron-left"}}
    {{i18n (or @label "back_button")}}
  </LinkTo>
</template>
