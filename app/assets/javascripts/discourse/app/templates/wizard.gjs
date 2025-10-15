import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import DiscourseLogo from "discourse/static/wizard/components/discourse-logo";

<template>
  {{hideApplicationSidebar}}
  {{hideApplicationFooter}}
  <div id="wizard-main">
    <DiscourseLogo />

    {{outlet}}
  </div>
</template>
