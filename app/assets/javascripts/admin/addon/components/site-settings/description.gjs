import { htmlSafe } from "@ember/template";

<template>
  <p class="desc form-kit-text form-kit__container-description">{{htmlSafe
      @description
    }}</p>
</template>
