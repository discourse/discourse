# frozen_string_literal: true

RSpec.describe Themes::BulkDestroy do
  fab!(:theme_1) { Fabricate(:theme) }
  fab!(:theme_2) { Fabricate(:theme) }
  fab!(:admin)

  subject(:result) { described_class.call(params:, **dependencies) }

  let(:params) { { theme_ids: [theme_1.id, theme_2.id] } }
  let(:dependencies) { { guardian: admin.guardian } }

  it "destroys the themes" do
    expect(result).to be_a_success
    expect(Theme.find_by(id: theme_1.id)).to be_nil
    expect(Theme.find_by(id: theme_2.id)).to be_nil
  end

  it "logs the theme destroys" do
    expect_any_instance_of(StaffActionLogger).to receive(:log_theme_destroy).with(theme_1).once
    expect_any_instance_of(StaffActionLogger).to receive(:log_theme_destroy).with(theme_2).once
    expect(result).to be_a_success
  end

  context "for invalid theme ids" do
    before do
      theme_1.destroy!
      theme_2.destroy!
    end

    it { is_expected.to fail_to_find_a_model(:themes) }
  end
end
