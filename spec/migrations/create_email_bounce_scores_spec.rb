# frozen_string_literal: true

require Rails.root.join("db/migrate/20260817214148_create_email_bounce_scores.rb")

RSpec.describe CreateEmailBounceScores do
  subject(:migrate) { described_class.new.migrate(:up) }

  before do
    @verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Base.connection.drop_table(:email_bounce_scores)
  end

  after { ActiveRecord::Migration.verbose = @verbose }

  it "seeds the primary address of every user currently in bad standing" do
    bouncing = Fabricate(:user)
    bouncing.user_stat.update!(bounce_score: 4.0, reset_bounce_score_after: 1.week.from_now)
    clean = Fabricate(:user)

    migrate

    expect(EmailBounceScore.score_for(bouncing.email)).to eq(4.0)
    expect(EmailBounceScore.for_email(clean.email)).to be_empty
  end

  it "ignores a score that is no longer in effect" do
    user = Fabricate(:user)
    user.user_stat.update!(bounce_score: 4.0, reset_bounce_score_after: nil)

    migrate

    expect(EmailBounceScore.for_email(user.email)).to be_empty
  end
end
