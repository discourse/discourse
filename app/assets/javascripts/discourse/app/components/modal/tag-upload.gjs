<DModal @title={{i18n "tagging.upload"}} @closeModal={{@closeModal}}>
  <:body>
    <TagsUploader
      @refresh={{route-action "triggerRefresh"}}
      @closeModal={{@closeModal}}
      @id="tags-uploader"
    />
  </:body>
</DModal>