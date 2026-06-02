import { hash } from "@ember/helper";
import AdminReport from "discourse/admin/components/admin-report";

<template>
  <AdminReport
    @dataSourceName={{@item.identifier}}
    @preloadedData={{@payload}}
    @showHeader={{false}}
    @bare={{true}}
    @filters={{hash startDate=@filters.startDate endDate=@filters.endDate}}
  />
</template>
