<p>{{i18n "topics.bulk.choose_new_category"}}</p>

<p>
  <CategoryChooser
    @value={{this.categoryId}}
    @onChange={{fn (mut this.categoryId)}}
  />
</p>

<ConditionalLoadingSpinner @condition={{@loading}}>
  <DButton
    @action={{this.changeCategory}}
    @label="topics.bulk.change_category"
  />
</ConditionalLoadingSpinner>