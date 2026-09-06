import AdSlot from "../../components/ad-slot";

const DiscourseAdplugin = <template>
  <span class="discovery-list-container-top-outlet discourse-adplugin">
    <AdSlot
      @placement="topic-list-top"
      @category={{@outletArgs.category.slug}}
    />
  </span>
</template>;

export default DiscourseAdplugin;
