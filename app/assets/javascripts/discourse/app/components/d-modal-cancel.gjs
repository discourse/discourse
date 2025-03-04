import DButton from "discourse/components/d-button";
import iN from "discourse/helpers/i18n";
<template>
  <DButton
    @action={{@close}}
    @translatedLabel={{iN "cancel"}}
    class="btn-flat d-modal-cancel"
  />
</template>
