import LightDarkImg from "discourse/components/light-dark-img";

const CategoryLogo = <template>
  <div class="category-logo aspect-image">
    <LightDarkImg
      @lightImg={{@category.uploaded_logo}}
      @darkImg={{@category.uploaded_logo_dark}}
    />
  </div>
</template>;

export default CategoryLogo;
