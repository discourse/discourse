import SemanticColorExample from "discourse/plugins/styleguide/discourse/components/semantic-color-example";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const SemanticColors = <template>
  <StyleguideExample @title="links & text">
    <section class="semantic-color-grid">
      <SemanticColorExample
        @color="d-link-color"
        @description="Default link color"
      />
      <SemanticColorExample
        @color="title-color"
        @description="Topic title color"
      />
      <SemanticColorExample
        @color="title-color--read"
        @description="Read topic title color"
      />
      <SemanticColorExample
        @color="excerpt-color"
        @description="Topic excerpt text"
      />
      <SemanticColorExample
        @color="metadata-color"
        @description="Metadata text"
      />
    </section>
  </StyleguideExample>

  <StyleguideExample @title="borders">
    <section class="semantic-color-grid">
      <SemanticColorExample
        @color="content-border-color"
        @description="Content area borders"
      />
      <SemanticColorExample
        @color="input-border-color"
        @description="Form input borders"
      />
      <SemanticColorExample
        @color="table-border-color"
        @description="Table borders"
      />
    </section>
  </StyleguideExample>

  <StyleguideExample @title="backgrounds">
    <section class="semantic-color-grid">
      <SemanticColorExample
        @color="mention-background-color"
        @description="Mention background"
      />
      <SemanticColorExample
        @color="d-badge-card-background-color"
        @description="Badge card background"
      />
      <SemanticColorExample @color="d-selected" @description="Selected state" />
      <SemanticColorExample @color="d-hover" @description="Hover state" />
    </section>
  </StyleguideExample>
</template>;

export default SemanticColors;
