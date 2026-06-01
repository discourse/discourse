import { trustHTML } from "@ember/template";
import linkifySettingLinks from "discourse/admin/modifiers/linkify-setting-links";

<template>
  <div class="desc" {{linkifySettingLinks @description}}>{{trustHTML
      @description
    }}</div>
</template>
