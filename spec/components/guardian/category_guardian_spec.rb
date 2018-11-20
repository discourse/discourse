require 'rails_helper'

RSpec.describe CategoryGuardian do
  let(:admin) { Fabricate(:admin) }
  let(:guardian) { Guardian.new(admin) }
  let(:category) { Fabricate(:category) }

  describe '#cannot_delete_category_reason' do
    describe 'when category is uncategorized' do
      it 'should return the reason' do
        category = Category.find(SiteSetting.uncategorized_category_id)

        expect(guardian.cannot_delete_category_reason(category)).to eq(
          I18n.t('category.cannot_delete.uncategorized')
        )
      end
    end

    describe 'when category has subcategories' do
      it 'should return the right reason' do
        category.subcategories << Fabricate(:category)

        expect(guardian.cannot_delete_category_reason(category)).to eq(
          I18n.t('category.cannot_delete.has_subcategories')
        )
      end
    end

    describe 'when category has topics' do
      it 'should return the right reason' do
        topic = Fabricate(:topic,
          title: '</a><script>alert(document.cookie);</script><a>',
          category: category
        )

        category.reload

        expect(guardian.cannot_delete_category_reason(category)).to eq(
          I18n.t('category.cannot_delete.topic_exists',
            count: 1,
            topic_link: "<a href=\"#{topic.url}\">&lt;/a&gt;&lt;script&gt;alert(document.cookie);&lt;/script&gt;&lt;a&gt;</a>"
          )
        )
      end
    end
  end
end
