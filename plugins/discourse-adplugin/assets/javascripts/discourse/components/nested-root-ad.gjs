import AdSlot from "./ad-slot";

const NestedRootAd = <template>
  <AdSlot
    @placement="nested-roots-between"
    @category={{@topic.category.slug}}
    @indexNumber={{@index}}
  />
</template>;

export default NestedRootAd;
