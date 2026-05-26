import { LinkTo } from "@ember/routing";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

<template>
  <LinkTo
    @route="adminPlugins.show.explorer.new"
    @model="discourse-data-explorer"
    class="de-manage-reports-hint"
  >
    <div class="de-manage-reports-hint__text">
      <span class="de-manage-reports-hint__title">
        {{i18n "data_explorer.manage_reports_hint.title"}}
      </span>
      <span class="de-manage-reports-hint__description">
        {{i18n "data_explorer.manage_reports_hint.description"}}
      </span>
    </div>
    {{dIcon "chevron-right" class="de-manage-reports-hint__chevron"}}
  </LinkTo>
</template>
