import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import { i18n } from "discourse-i18n";

const BlogThemePreview = <template>
  {{#let @model.editor as |editor|}}
    <DModal
      class="--max blog-theme-preview"
      @closeModal={{@closeModal}}
      @title={{i18n "blog.admin.preview_short"}}
    >
      <:body>
        <p class="blog-theme-preview__hint">{{i18n
            "blog.admin.working_preview_hint"
          }}</p>
        <div class="blog-theme-preview__controls">
          <DNativeSelect
            aria-label={{i18n "blog.admin.preview_page"}}
            @includeNone={{false}}
            @onChange={{editor.selectPreviewPage}}
            @value={{editor.previewPage}}
            as |select|
          >
            <select.Option @value="index">{{i18n
                "blog.admin.preview_home"
              }}</select.Option>
            <select.Option @value="archive">{{i18n
                "blog.admin.preview_archive"
              }}</select.Option>
            <select.Option @value="article">{{i18n
                "blog.admin.preview_article"
              }}</select.Option>
            <select.Option @value="about">{{i18n
                "blog.admin.template_about"
              }}</select.Option>
            <select.Option @value="not_found">{{i18n
                "blog.admin.template_not_found"
              }}</select.Option>
          </DNativeSelect>
          <DNativeSelect
            aria-label={{i18n "blog.admin.sample_article"}}
            @includeNone={{false}}
            @onChange={{editor.selectPreviewArticle}}
            @value={{editor.selectedArticle}}
            as |select|
          >{{#each editor.articleOptions as |article|}}<select.Option
                @value={{article.id}}
              >{{article.title}}</select.Option>{{/each}}</DNativeSelect>
          <DNativeSelect
            aria-label={{i18n "blog.admin.preview_size"}}
            @includeNone={{false}}
            @onChange={{editor.selectDevice}}
            @value={{editor.previewDevice}}
            as |select|
          ><select.Option @value="desktop">{{i18n
                "blog.admin.desktop"
              }}</select.Option><select.Option @value="mobile">{{i18n
                "blog.admin.mobile"
              }}</select.Option></DNativeSelect>
          <DConditionalLoadingSpinner
            @condition={{editor.busy}}
            @size="small"
          />
        </div>
        {{#if editor.previewUnavailable}}
          <p class="blog-theme-preview__empty">{{i18n
              "blog.admin.preview_article_unavailable"
            }}</p>
        {{else}}
          {{#if editor.previewUrl}}
            <div class="blog-theme-preview__scroll"><iframe
                class="blog-theme-preview__frame"
                data-size={{editor.previewDevice}}
                sandbox="allow-scripts allow-same-origin allow-forms"
                src={{editor.previewUrl}}
                title={{i18n "blog.admin.preview_short"}}
              ></iframe></div>
            <p class="blog-theme-preview__link"><a
                href={{editor.previewUrl}}
                rel="noopener noreferrer"
                target="_blank"
              >{{i18n "blog.admin.open_working_preview"}}</a></p>
          {{/if}}
        {{/if}}
      </:body>
      <:footer>
        <DButton @action={{@closeModal}} @label="close" />
      </:footer>
    </DModal>
  {{/let}}
</template>;

export default BlogThemePreview;
