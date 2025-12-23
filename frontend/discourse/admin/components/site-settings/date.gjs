import { Input } from "@ember/component";

<template>
  <Input
    @type="date"
    @value={{@value}}
    class="input-setting-date"
    @disabled={{@disabled}}
  />
</template>
