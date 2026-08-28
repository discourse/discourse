import AdSlot from "../../components/ad-slot";

const DiscourseAdplugin = <template>
  <div class="topic-above-suggested-outlet discourse-adplugin">
    <AdSlot
      @placement="topic-above-suggested"
      @category={{@outletArgs.model.category.slug}}
    />
  </div>
</template>;

export default DiscourseAdplugin;
