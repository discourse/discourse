import i18n from "discourse-common/helpers/i18n";

<template>
  <div class="admin-plugin-config-page__metadata">
    <div class="admin-plugin-config-area__metadata-title">
      <h2>
        {{@plugin.nameTitleized}}
      </h2>
      <p>
        {{@plugin.about}}
        {{#if @plugin.linkUrl}}
          |
          <a href={{@plugin.linkUrl}} rel="noopener noreferrer" target="_blank">
            {{i18n "admin.plugins.learn_more"}}
          </a>
        {{/if}}
      </p>
    </div>
  </div>
</template>
