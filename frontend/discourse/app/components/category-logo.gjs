import LightDarkImg from "discourse/ui-kit/d-light-dark-img";

const CategoryLogo = <template>
  <div class="category-logo aspect-image" ...attributes>
    <LightDarkImg
      @lightImg={{@category.uploaded_logo}}
      @darkImg={{@category.uploaded_logo_dark}}
    />
  </div>
</template>;

export default CategoryLogo;
