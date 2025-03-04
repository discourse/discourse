import { on } from "@ember/modifier";
import htmlSafe from "discourse/helpers/html-safe";
import iN from "discourse/helpers/i18n";
<template><div class="composer-fullscreen-prompt" {{on "animationend" @removeFullScreenExitPrompt}}>
  {{htmlSafe (iN "composer.exit_fullscreen_prompt")}}
</div></template>