import EditCategoryTypeSchemaFields from "discourse/admin/components/edit-category-type-schema-fields";

const UpsertCategorySupport = <template>
  <EditCategoryTypeSchemaFields
    @category={{@category}}
    @categoryType="support"
    @form={{@form}}
  />
</template>;

export default UpsertCategorySupport;
