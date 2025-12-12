import didInsert from "@ember/render-modifiers/modifiers/did-insert";

/**
 * DScroll.Content - The scrollable content wrapper.
 *
 * This component represents the content that moves as scroll occurs.
 *
 * @component
 * @param {Object} controller - The scroll controller instance
 */
const DScrollContent = <template>
  <div
    data-d-scroll="content"
    {{didInsert @controller.registerContent}}
    ...attributes
  >
    {{yield}}
  </div>
</template>;

export default DScrollContent;
