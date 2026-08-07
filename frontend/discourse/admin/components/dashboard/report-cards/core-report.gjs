import AdminReport from "discourse/admin/components/admin-report";

export default <template>
  <AdminReport
    @dataSourceName={{@item.identifier}}
    @preloadedData={{@payload}}
    @showHeader={{false}}
    @bare={{true}}
  />
</template>
