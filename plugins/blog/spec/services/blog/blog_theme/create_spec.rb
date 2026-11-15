# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::Create do
  describe described_class::Contract, type: :model do
    subject(:contract) do
      described_class.new(
        name: "Quiet draft",
        accent_color: "112233",
        paper_color: "fafafa",
        ink_color: "222222",
        css: "",
        javascript: "",
      )
    end

    it do
      is_expected.to allow_value("<h1>{{ site.title }}</h1>").for(:template_index).with_message(
        /Invalid Liquid template/,
        against: :base,
      )
    end

    it do
      is_expected.not_to allow_value("{% unknown_tag %}").for(:template_index).with_message(
        /Invalid Liquid template: index: /,
        against: :base,
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, options:, **dependencies) }

    fab!(:acting_user, :admin)

    let(:params) do
      {
        name: "Quiet draft",
        accent_color: "112233",
        paper_color: "fafafa",
        ink_color: "222222",
        css: ".blog { color: red; }",
        javascript: "",
      }
    end
    let(:options) { {} }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when contract is invalid" do
      let(:params) { super().merge(name: "") }

      it { is_expected.to fail_a_contract }
    end

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_themes) }
    end

    context "when the theme limit is reached" do
      around { |example| stub_const(Blog::BlogTheme, :MAX_THEMES, 1) { example.run } }

      before { create_blog_theme(params, user: acting_user) }

      it { is_expected.to fail_a_policy(:within_theme_limit) }
    end

    context "when another create holds the lock" do
      before { DistributedMutex.stubs(:synchronize).returns(nil) }

      it "saves nothing" do
        expect(result).to be_a_failure
        expect(result["result.lock."]).to be_a_failure
        expect(Blog::BlogTheme.count).to eq(0)
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves an inactive first revision" do
        expect(result.theme).to include(
          "name" => "Quiet draft",
          "css" => ".blog { color: red; }",
          "template_index" => "",
          "revision" => 1,
          "source" => nil,
          "locally_modified" => false,
        )
        expect(Blog::BlogTheme.find(result.theme["id"])).to eq(result.theme)
        expect(Blog::BlogTheme.active["id"]).to eq(Blog::ThemePresets::DEFAULT_ID)
      end

      it "logs the save" do
        expect { result }.to change {
          UserHistory.where(acting_user_id: acting_user.id, custom_type: "blog_theme_save").count
        }.by(1)
      end
    end

    context "with a Git source" do
      let(:options) do
        { source: { "repository" => "https://github.com/example/theme", "commit" => "abc" } }
      end

      it "records where the theme came from" do
        expect(result.theme["source"]).to eq(options[:source])
      end
    end
  end
end
