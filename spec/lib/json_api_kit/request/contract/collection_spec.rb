# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Contract::Collection, type: :model do
  subject(:contract) do
    described_class.new(
      **params,
      options: {
        resource:,
        raw_parameters: params.with_indifferent_access,
      },
    )
  end

  let(:params) { {} }
  let(:cursor) { JsonApiKit::Pagination::Cursor.new([resource.order.digest, 0, 12]).to_s }
  let(:related) do
    Class.new(JsonApiKit::Resource) do
      model User
      type :users
    end
  end
  let(:resource) do
    users = related
    Class.new(JsonApiKit::Resource) do
      has_one :user, resource: users
      model Topic
      type :topics
      sort :created_at
      sort :title
      filter :title
      anchor :id
      anchor :title
      page max: 50
      anchor(:first_unread) { |topics, _guardian| topics }
    end
  end

  describe "Unknown parameters" do
    context "when a parameter is unknown" do
      let(:params) { { sorts: { created_at: :asc } } }

      it "refuses the parameter" do
        expect(contract).to be_invalid
        expect(contract.errors).to include(:sorts)
      end
    end

    context "when a page parameter is unknown" do
      let(:params) { { page: { sise: 2 } } }

      it "refuses it under the parameter it came in" do
        expect(contract).to be_invalid
        expect(contract.errors).to include(:"page.sise")
      end
    end
  end

  describe "Sorting" do
    it { is_expected.to allow_value(nil, {}, { created_at: :asc }).for(:sort) }
    it { is_expected.to allow_value({ created_at: :desc, title: :asc }).for(:sort) }
    it { is_expected.not_to allow_value({ secrets: :asc }).for(:sort) }
    it { is_expected.not_to allow_value({ created_at: :sideways }).for(:sort) }
    it { is_expected.not_to allow_value("created_at", %w[created_at], 5, "").for(:sort) }
  end

  describe "Filtering" do
    it { is_expected.to allow_value(nil, {}, { title: "a topic" }).for(:filter) }
    it { is_expected.not_to allow_value({ secrets: "hidden" }).for(:filter) }
    it { is_expected.not_to allow_value("title", %w[title], "").for(:filter) }
    it { is_expected.not_to allow_value({ title: { a: 1 } }, { title: {} }).for(:filter) }
  end

  describe "Including" do
    it { is_expected.to allow_value(nil, [], %w[user]).for(:include) }
    it { is_expected.to allow_value("", [""]).for(:include) }
    it { is_expected.not_to allow_value(%w[secrets], %w[user.groups]).for(:include) }
  end

  describe "Fieldsets" do
    it { is_expected.to allow_value(nil, {}, { topics: %w[title created_at] }).for(:fields) }
    it { is_expected.not_to allow_value("title", [1], { topics: 42 }).for(:fields) }
    it { is_expected.not_to allow_value({ topics: "title" }).for(:fields) }
  end

  describe "Anchoring" do
    subject(:page) { contract.page }

    let(:params) { { page: {} } }

    before { contract.valid? }

    it { is_expected.to validate_length_of(:anchor).as_array.is_equal_to(1).allow_nil }
    it { is_expected.to allow_value({ id: 12 }, :first_unread).for(:anchor) }
    it { is_expected.not_to allow_value({}, { id: 12, title: "a topic" }).for(:anchor) }
    it { is_expected.not_to allow_value({ id: { a: 1 } }, { id: %w[a b] }).for(:anchor) }
    it { is_expected.not_to allow_value({ secrets: 12 }, :guesswork).for(:anchor) }

    context "when the anchor name matches the sort" do
      let(:params) { { sort: { title: :asc }, page: {} } }

      it { is_expected.to allow_value({ title: "a topic" }).for(:anchor) }
    end

    context "when the anchor name does not match the sort" do
      let(:params) { { sort: { created_at: :asc }, page: {} } }

      it { is_expected.not_to allow_value({ title: "a topic" }).for(:anchor) }
      it { is_expected.to allow_value({ id: 12 }, :first_unread).for(:anchor) }
    end

    context "when a cursor is present" do
      let(:params) { { page: { after: cursor } } }

      it { is_expected.to validate_absence_of(:anchor) }
    end

    context "when a window is requested" do
      let(:params) { { page: { before_size: 2 } } }

      it { is_expected.to validate_presence_of(:anchor) }
    end

    context "when the anchor is not included" do
      let(:params) { { page: { include_anchor: false } } }

      it { is_expected.to validate_presence_of(:anchor) }
    end
  end

  describe "Pagination" do
    subject(:page) { contract.page }

    let(:params) { { page: {} } }
    let(:cursor_not_matching_segment) do
      JsonApiKit::Pagination::Cursor.new([resource.order.digest, 7, 12]).to_s
    end
    let(:cursor_not_matching_length) do
      JsonApiKit::Pagination::Cursor.new([resource.order.digest, 0]).to_s
    end

    before { contract.valid? }

    it do
      is_expected.to validate_numericality_of(:size)
        .only_integer
        .is_greater_than(0)
        .is_less_than_or_equal_to(50)
        .allow_nil
    end
    it { is_expected.not_to allow_value("").for(:size) }
    it { is_expected.to allow_value(cursor).for(:after) }
    it { is_expected.to allow_value(cursor).for(:before) }
    it do
      is_expected.not_to allow_value(
        "not-a-cursor",
        "",
        cursor_not_matching_length,
        cursor_not_matching_segment,
      ).for(:after)
    end
    it do
      is_expected.not_to allow_value(
        "not-a-cursor",
        "",
        cursor_not_matching_segment,
        cursor_not_matching_length,
      ).for(:before)
    end

    context "when there is no page" do
      let(:params) { {} }

      it { expect(contract).to be_valid }
    end

    context "when the page is not a valid object" do
      let(:params) { { page: "big" } }

      it { expect(contract).not_to be_valid }
    end

    context "when page[after] is present" do
      let(:params) { { page: { after: cursor } } }

      it { is_expected.to validate_absence_of(:before) }
    end

    context "when page[before] is present" do
      let(:params) { { page: { before: cursor } } }

      it { is_expected.to validate_absence_of(:after) }
    end
  end

  describe "Anchor window" do
    subject(:page) { contract.page }

    let(:params) { { page: {} } }

    before { contract.valid? }

    it do
      is_expected.to validate_numericality_of(:before_size)
        .only_integer
        .is_greater_than_or_equal_to(0)
        .allow_nil
    end
    it do
      is_expected.to validate_numericality_of(:after_size)
        .only_integer
        .is_greater_than_or_equal_to(0)
        .allow_nil
    end
    it { is_expected.not_to allow_value("").for(:before_size) }
    it { is_expected.not_to allow_value("").for(:after_size) }

    context "when both `page[before_size]` and `page[after_size]` are provided" do
      let(:params) { { page: { anchor: { id: 12 }, before_size: 25 } } }

      it { is_expected.to allow_value(20).for(:after_size).against(:window_size) }
      it { is_expected.not_to allow_value(25).for(:after_size).against(:window_size) }

      context "when `page[include_anchor]` is false" do
        let(:params) { { anchor: { id: 12 }, page: { before_size: 25, include_anchor: false } } }

        it { is_expected.to allow_value(25).for(:after_size).against(:window_size) }
      end

      context "when both sides are 0" do
        let(:params) { { anchor: { id: 12 }, page: { before_size: 0, include_anchor: false } } }

        it { is_expected.not_to allow_value(0).for(:after_size).against(:window_size) }
      end
    end
  end
end
