import { hash } from "@ember/helper";
import PluginOutlet from "./plugin-outlet";

<template>
  <PluginOutlet @name="after-post" @outletArgs={{hash post=@data.post}} />
</template>
