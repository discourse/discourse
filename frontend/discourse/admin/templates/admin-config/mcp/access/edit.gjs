import AdminMcp from "discourse/admin/components/admin-mcp";

export default <template>
  <AdminMcp @section="access-edit" @model={{@model}} />
</template>
