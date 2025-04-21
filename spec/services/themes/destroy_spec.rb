# frozen_string_literal: true

RSpec.describe Themes::Destroy do
  fab!(:theme)
  fab!(:admin)

  subject(:result) { described_class.call(params:, **dependencies) }

  let(:params) { { id: theme.id } }
  let(:dependencies) { { guardian: admin.guardian } }

  it "destroys the theme" do
    expect(result).to be_a_success
    expect(Theme.find_by(id: theme.id)).to be_nil
  end

  it "logs the theme destroy" do
    expect_any_instance_of(StaffActionLogger).to receive(:log_theme_destroy).with(theme)
    expect(result).to be_a_success
  end

  context "for invalid theme id" do
    before { theme.destroy! }

    it { is_expected.to fail_to_find_a_model(:theme) }
  end
end
