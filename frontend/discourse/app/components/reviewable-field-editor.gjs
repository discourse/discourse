import DEditor from "discourse/ui-kit/d-editor";

const ReviewableFieldEditor = <template>
  <DEditor @change={{@valueChanged}} @value={{@value}} />
</template>;

export default ReviewableFieldEditor;
