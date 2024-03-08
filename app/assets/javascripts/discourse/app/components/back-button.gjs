import { LinkTo } from "@ember/routing";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

<template>
  <LinkTo
    class="btn btn-flat back-button"
    @label={{i18n @label}}
    @route={{@route}}
  >
    {{dIcon "chevron-left"}}
    {{i18n "back_button"}}
  </LinkTo>
</template>
