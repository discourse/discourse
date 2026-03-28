# frozen_string_literal: true

RSpec.describe Jobs::DownloadBackupEmail do
  fab!(:user, :admin)

  before { SiteSetting.simple_email_subject = true }

  it "should work" do
    described_class.new.execute(user_id: user.id, backup_file_path: "http://some.example.test/")

    email = ActionMailer::Base.deliveries.last

    expect(email.subject).to eq(
      I18n.t("download_backup_mailer.subject_template_improved", email_prefix: SiteSetting.title),
    )

    expect(email.body.raw_source).to include(
      "http://some.example.test/?token=#{EmailBackupToken.get(user.id)}",
    )
  end
end
