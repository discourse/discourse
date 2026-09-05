import AdminMcp from "discourse/admin/components/admin-mcp";

export default <template>
  <AdminMcp @section="access-new" @model={{@model}} />
</template>
