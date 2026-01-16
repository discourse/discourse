import TagSettings from "discourse/components/tag-settings";

<template>
  <TagSettings
    @tag={{@model}}
    @selectedTab={{@controller.selectedTab}}
    @parentParams={{@controller.parentParams}}
  />
</template>
