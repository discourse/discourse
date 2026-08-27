import AdSlot from "../../components/ad-slot";

const DiscourseAdplugin = <template>
  <div class="above-site-header-outlet discourse-adplugin">
    <AdSlot
      @placement="above-site-header"
      @category={{@outletArgs.category.slug}}
    />
  </div>
</template>;

export default DiscourseAdplugin;
