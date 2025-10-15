import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";

<template>
  <ComposerTipCloseButton
    @action={{fn @controller.closeMessage @controller.message}}
  />

  <p>
    {{htmlSafe @controller.message.body}}
  </p>
</template>
