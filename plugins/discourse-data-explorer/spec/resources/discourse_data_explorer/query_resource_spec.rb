# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::QueryResource, type: :resource do
  fab!(:admin)

  it { is_expected.to declare_model(DiscourseDataExplorer::Query) }
  it { is_expected.to declare_type(:queries) }
  it { is_expected.to declare_namespace("data-explorer") }

  it { is_expected.to expose(:name, :description, :created_at, :last_run_at) }
  it { is_expected.to expose(:param_info, :is_default) }
  it { is_expected.to expose(:sql).readable_by(admin.guardian).hidden_from(Guardian.new) }

  it { is_expected.to have_one(:user) }
  it { is_expected.to have_many(:groups) }

  it { is_expected.to sort_on(:name, :last_run_at, "user.username") }
  it { is_expected.to sort_by_default(last_run_at: :desc) }

  it { is_expected.to filter_on(:search) }
  it { is_expected.to anchor_on(:id, :name, :last_run_at) }

  it { is_expected.to paginate(default: 50, max: 100) }
end
