# frozen_string_literal: true

RSpec.describe Categories::Configure do
  describe Categories::Configure::Contract, type: :model do
    it { is_expected.to validate_presence_of(:category_id) }
    it { is_expected.to validate_presence_of(:category_type) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:category)

    let(:params) { { category_id: category.id, category_type: "discussion" } }
    let(:dependencies) { { guardian: admin.guardian } }

    def build_test_type(id, enables_plugin: false, plugin_enabled: true)
      Class.new(Categories::Types::Base) do
        type_id id

        define_singleton_method(:enable_plugin) {} if enables_plugin
        define_singleton_method(:plugin_enabled?) { plugin_enabled } if enables_plugin
        define_singleton_method(:category_matches?) { |_| false }
        define_singleton_method(:find_matches) { Category.none }
        define_singleton_method(:configure_category) { |_, guardian:, configuration_values: {}| }
        define_singleton_method(:unconfigure_category) { |_, guardian:| }
      end
    end

    context "when params are invalid" do
      let(:params) { { category_id: nil, category_type: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when category type is invalid" do
      let(:params) { super().merge(category_type: "invalid_type") }

      it { is_expected.to fail_a_contract }
    end

    context "when category is not found" do
      let(:params) { super().merge(category_id: -1) }

      it { is_expected.to fail_to_find_a_model(:category) }
    end

    context "when user cannot modify category" do
      fab!(:user)
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_modify_category) }
    end

    context "when type is not available" do
      before { allow(Categories::Types::Discussion).to receive(:available?).and_return(false) }

      it { is_expected.to fail_a_policy(:type_is_available) }
    end

    context "when type does not enable a plugin (Discussion)" do
      context "when user is a moderator" do
        fab!(:moderator)

        let(:dependencies) { { guardian: moderator.guardian } }

        before { SiteSetting.moderators_manage_categories = true }

        it { is_expected.to run_successfully }
      end
    end

    context "when type enables a plugin that is not yet enabled" do
      let(:test_type_class) do
        build_test_type(:test_plugin_type, enables_plugin: true, plugin_enabled: false)
      end
      let(:params) { { category_id: category.id, category_type: "test_plugin_type" } }

      before { Categories::TypeRegistry.register(test_type_class) }
      after { Categories::TypeRegistry.reset! }

      context "when user is a moderator" do
        fab!(:moderator)

        let(:dependencies) { { guardian: moderator.guardian } }

        before { SiteSetting.moderators_manage_categories = true }

        it { is_expected.to fail_a_policy(:type_is_available) }
      end

      context "when user is an admin" do
        it { is_expected.to run_successfully }
      end
    end

    context "when type enables a plugin that is already enabled" do
      let(:test_type_class) do
        build_test_type(:test_plugin_type_enabled, enables_plugin: true, plugin_enabled: true)
      end
      let(:params) { { category_id: category.id, category_type: "test_plugin_type_enabled" } }

      before { Categories::TypeRegistry.register(test_type_class) }
      after { Categories::TypeRegistry.reset! }

      context "when user is a moderator" do
        fab!(:moderator)

        let(:dependencies) { { guardian: moderator.guardian } }

        before { SiteSetting.moderators_manage_categories = true }

        it { is_expected.to run_successfully }
      end

      context "when user is an admin" do
        it { is_expected.to run_successfully }
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "calls enable_plugin on the type class" do
        Categories::Types::Discussion.stubs(:plugin_enabled?).returns(true)
        Categories::Types::Discussion.expects(:enable_plugin).once
        result
      end

      it "calls configure_site_settings on the type class" do
        Categories::Types::Discussion.expects(:configure_site_settings).once
        result
      end

      it "calls configure_category on the type class" do
        Categories::Types::Discussion.expects(:configure_category).once
        result
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          action: UserHistory.actions[:custom_staff],
          custom_type: "configure_category_type",
          acting_user_id: admin.id,
        )
        expect(UserHistory.last.details).to include("category_type")
      end

      it "clears the category type counts cache" do
        Discourse.cache.write(Categories::TypeRegistry::COUNTS_CACHE_KEY, "cached_value")
        result
        expect(Discourse.cache.read(Categories::TypeRegistry::COUNTS_CACHE_KEY)).to be_nil
      end

      it "clears the site categories cache so `category_types` propagates" do
        Site.expects(:clear_cache).at_least_once
        result
      end
    end
  end
end
