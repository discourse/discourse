import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { or } from "discourse/truth-helpers";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

<template>
  <LinkTo
    class="btn btn-transparent back-button"
    @route={{@route}}
    @models={{if @model (array @model) (array)}}
  >
    {{icon "chevron-left"}}
    {{i18n (or @label "back_button")}}
  </LinkTo>
</template>
