import AdminReports from "discourse/admin/components/admin-reports";

export default <template>
  <div class="admin-config-area__full-width">
    <AdminReports
      @group={{@controller.group}}
      @onGroupChange={{@controller.updateGroupFilter}}
    />
  </div>
</template>
