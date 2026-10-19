import AdminReport from "discourse/admin/components/admin-report";

export default <template>
  <AdminReport
    @bare={{true}}
    @dataSourceName={{@item.identifier}}
    @preloadedData={{@payload}}
    @showHeader={{false}}
  />
</template>
