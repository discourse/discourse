import AdSlot from "../../components/ad-slot";

const DiscourseAdplugin = <template>
  <div class="topic-above-suggested-outlet discourse-adplugin">
    <AdSlot
      @category={{@outletArgs.model.category.slug}}
      @placement="topic-above-suggested"
    />
  </div>
</template>;

export default DiscourseAdplugin;
