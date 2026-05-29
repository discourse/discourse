import AdminReport from "discourse/admin/components/admin-report";

<template>
  <AdminReport
    @dataSourceName={{@item.identifier}}
    @preloadedData={{@payload}}
    @showHeader={{false}}
    @bare={{true}}
  />
</template>
