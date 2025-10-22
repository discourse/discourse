import AdSlot from "./ad-slot";

const PostBottomAd = <template>
  <AdSlot
    @placement="post-bottom"
    @category={{@model.topic.category.slug}}
    @postNumber={{@model.post_number}}
  />
</template>;

export default PostBottomAd;
