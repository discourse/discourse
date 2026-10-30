# frozen_string_literal: true

RSpec.describe "Viewing categories with group permissions" do
  fab!(:group)
  fab!(:user)
  fab!(:member, :user) { Fabricate(:user, groups: [group]) }
  fab!(:public_category, :category)
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:logged_in_category) { Fabricate(:category, permissions: { logged_in_users: :readonly }) }
  fab!(:public_topic) { Fabricate(:topic, category: public_category) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:logged_in_topic) { Fabricate(:topic, category: logged_in_category) }

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:category_list) { PageObjects::Components::CategoryList.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:not_found_page) { PageObjects::Pages::NotFound.new }

  shared_examples "category visibility" do |enabled:, viewer:|
    context "with granular permissions #{enabled}" do
      before { SiteSetting.granular_anonymous_and_logged_in_groups_permissions = enabled }

      it "lets a #{viewer} browse permitted categories and see a not-found page for denied categories" do
        sign_in(viewer == :member ? member : user) unless viewer == :anonymous

        visible_categories = [public_category]
        visible_categories << private_category if viewer == :member
        visible_categories << logged_in_category if viewer != :anonymous

        category_page.visit_categories

        [public_category, private_category, logged_in_category].each do |category|
          if visible_categories.include?(category)
            expect(category_list).to have_category(category)
          else
            expect(category_list).to have_no_category(category)
          end
        end

        [public_topic, private_topic, logged_in_topic].each do |topic|
          category_page.visit(topic.category)

          if visible_categories.include?(topic.category)
            expect(topic_list).to have_topic(topic)
          else
            expect(not_found_page).to be_visible
          end
        end
      end
    end
  end

  it_behaves_like "category visibility", enabled: false, viewer: :anonymous
  it_behaves_like "category visibility", enabled: false, viewer: :nonmember
  it_behaves_like "category visibility", enabled: false, viewer: :member
  it_behaves_like "category visibility", enabled: true, viewer: :anonymous
  it_behaves_like "category visibility", enabled: true, viewer: :nonmember
  it_behaves_like "category visibility", enabled: true, viewer: :member
end
