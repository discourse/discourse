import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";

<template>
  {{bodyClass "static-tos"}}

  <section class="container">
    <div class="contents clearfix body-page">
      <PluginOutlet @name="above-static" />
      {{htmlSafe @controller.model.html}}
      <PluginOutlet @name="below-static" />
    </div>
  </section>
</template>
