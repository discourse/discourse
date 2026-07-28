# frozen_string_literal: true

RSpec.describe ListAdminCategories do
  describe described_class::Contract, type: :model do
    it { is_expected.to allow_values(1, ListAdminCategories::MAX_PER_PAGE).for(:per_page) }
    it { is_expected.not_to allow_values(0, ListAdminCategories::MAX_PER_PAGE + 1).for(:per_page) }
    it { is_expected.to allow_values(0, 1).for(:page) }
    it { is_expected.not_to allow_values(-1).for(:page) }

    it "defaults to the discussion category type" do
      contract = described_class.new(type: nil)

      contract.valid?

      expect(contract.type_id).to eq("discussion")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:alpha_category) { Fabricate(:category, name: "Alpha", slug: "alpha") }
    fab!(:beta_category) { Fabricate(:category, name: "Beta", slug: "beta") }

    let(:params) { { type: "all", page: 0, per_page: 2 } }
    let(:dependencies) { { guardian: admin.guardian } }

    around do |example|
      types = Categories::TypeRegistry.all.dup
      owners = types.keys.index_with { |type_id| Categories::TypeRegistry.owner(type_id) }

      example.run
    ensure
      Categories::TypeRegistry.instance_variable_set(:@types, types)
      Categories::TypeRegistry.instance_variable_set(:@owners, owners)
    end

    context "when contract is invalid" do
      let(:params) { super().merge(per_page: 0) }

      it { is_expected.to fail_a_contract }
    end

    context "when category type is unknown" do
      let(:params) { super().merge(type: "unknown") }

      it { is_expected.to fail_a_policy(:category_type_exists) }
    end

    context "when everything is valid" do
      fab!(:gamma_category) { Fabricate(:category, name: "Gamma", slug: "gamma") }

      it { is_expected.to run_successfully }

      it "returns the first page of ordered categories with pagination state" do
        expect(result.category_page[:categories]).to eq([alpha_category, beta_category])
        expect(result.category_page[:has_more]).to eq(true)
      end

      context "with a later page" do
        let(:params) { super().merge(page: 1) }

        it "returns categories offset by the requested page" do
          expect(result.category_page[:categories].first).to eq(gamma_category)
          expect(result.category_page[:has_more]).to eq(false)
        end
      end
    end

    context "with a filter" do
      let(:params) { super().merge(filter: "alp") }

      it "returns matching categories" do
        expect(result.category_page[:categories]).to contain_exactly(alpha_category)
      end
    end

    context "with public visibility" do
      fab!(:private_group, :group)
      fab!(:restricted_category) do
        Fabricate(:private_category, group: private_group, name: "Restricted")
      end

      let(:params) { super().merge(visibility: "public") }

      it "returns only public categories" do
        expect(result.category_page[:categories]).to contain_exactly(alpha_category, beta_category)
      end
    end

    context "with restricted visibility" do
      fab!(:private_group, :group)
      fab!(:restricted_category) do
        Fabricate(:private_category, group: private_group, name: "Restricted")
      end

      let(:params) { super().merge(visibility: "restricted") }

      it "returns only restricted categories" do
        expect(result.category_page[:categories]).to contain_exactly(restricted_category)
      end
    end

    context "with a category type filter" do
      let(:test_type) do
        Class.new(Categories::Types::Base) do
          type_id :test_list_admin_categories

          define_singleton_method(:category_matches?) { |category| category.name == "Alpha" }

          define_singleton_method(:find_matches) { Category.where(name: "Alpha") }
        end
      end
      let(:params) { super().merge(type: "test_list_admin_categories") }

      before { Categories::TypeRegistry.register(test_type) }

      it "returns categories matching the requested category type" do
        expect(result.category_page[:categories]).to contain_exactly(alpha_category)
      end
    end

    context "with preloaded category custom fields" do
      before do
        Site.reset_preloaded_category_custom_fields
        Site.preloaded_category_custom_fields << "list_admin_categories_field"
        alpha_category.custom_fields["list_admin_categories_field"] = "alpha value"
        beta_category.custom_fields["list_admin_categories_field"] = "beta value"
        alpha_category.save_custom_fields
        beta_category.save_custom_fields
      end

      after { Site.reset_preloaded_category_custom_fields }

      it "makes registered custom fields available without per-category refresh queries" do
        result

        queries =
          track_sql_queries do
            result.category_page[:categories].map do |category|
              category.custom_fields["list_admin_categories_field"]
            end
          end

        values =
          result.category_page[:categories].map do |category|
            category.custom_fields["list_admin_categories_field"]
          end

        expect(values).to eq(["alpha value", "beta value"])
        expect(
          queries.grep(
            /FROM "category_custom_fields".*WHERE "category_custom_fields"."category_id"/,
          ),
        ).to be_empty
      end
    end
  end
end
