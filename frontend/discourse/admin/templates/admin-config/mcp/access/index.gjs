import AdminMcp from "discourse/admin/components/admin-mcp";

export default <template>
  <AdminMcp @section="access" @model={{@model}} />
</template>
