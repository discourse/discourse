import dIcon from "discourse/helpers/d-icon";
import iN from "discourse/helpers/i18n";
<template>{{#if @model.members.length}}
  <p>
    {{dIcon "users"}}
    {{iN "admin.groups.delete_details" count=@model.members.length}}
  </p>
{{/if}}
{{#if @model.message_count}}
  <p>
    {{dIcon "envelope"}}
    {{iN "admin.groups.delete_with_messages_confirm" count=@model.message_count}}
  </p>
{{/if}}

<p>
  {{dIcon "triangle-exclamation"}}
  {{iN "admin.groups.delete_warning"}}
</p></template>