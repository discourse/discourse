import concatClass from "discourse/helpers/concat-class";
import gt from "truth-helpers/helpers/gt";
import iN from "discourse/helpers/i18n";
<template><div class={{concatClass "char-counter" (if (gt @value.length @max) "exceeded")}} ...attributes>
  {{yield}}
  <small class="char-counter__ratio">
    {{@value.length}}/{{@max}}
  </small>
  <span aria-live="polite" class="sr-only">
    {{if (gt @value.length @max) (iN "char_counter.exceeded")}}
  </span>
</div></template>