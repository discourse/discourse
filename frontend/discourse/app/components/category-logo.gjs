import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";

const CategoryLogo = <template>
  <div class="category-logo aspect-image" ...attributes>
    <DLightDarkImg
      @darkImg={{@category.uploaded_logo_dark}}
      @lightImg={{@category.uploaded_logo}}
    />
  </div>
</template>;

export default CategoryLogo;
