// @ts-check
/** @type {import("discourse/ui-kit/d-light-dark-img.gjs")} */
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";

/**
 * Renders a category's logo, swapping between its light and dark uploads per
 * the active color scheme. The consumer's `...attributes` are forwarded to the
 * wrapper element.
 *
 * @type {import("@ember/component/template-only").TOC<{
 *   Args: { category?: any },
 *   Element: HTMLDivElement,
 * }>}
 */
const CategoryLogo = <template>
  <div class="category-logo aspect-image" ...attributes>
    <DLightDarkImg
      @lightImg={{@category.uploaded_logo}}
      @darkImg={{@category.uploaded_logo_dark}}
    />
  </div>
</template>;

export default CategoryLogo;
