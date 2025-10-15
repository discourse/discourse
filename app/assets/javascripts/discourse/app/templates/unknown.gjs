import { htmlSafe } from "@ember/template";

<template>
  <div class="container">
    {{htmlSafe @controller.model}}
  </div>
</template>
