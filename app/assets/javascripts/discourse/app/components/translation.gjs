import { i18n } from "discourse-i18n";

<template>
  <span class="i18n-container">
    {{i18n @scope @options}}
    {{yield}}
  </span>
</template>
