import EditCategoryTypeSchemaFields from "discourse/components/edit-category-type-schema-fields";

const UpsertCategorySupport = <template>
  <EditCategoryTypeSchemaFields
    @category={{@category}}
    @categoryType="support"
    @form={{@form}}
  />
</template>;

export default UpsertCategorySupport;
