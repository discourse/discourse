# frozen_string_literal: true

describe ReadOnlyMixin do
  before { Rails.application.eager_load! }

  it "allows only these actions in readonly mode" do
    controllers_with_readonly_actions = []

    ApplicationController.descendants.each do |controller_class|
      controller_class.actions_allowed_in_readonly_mode&.each do |action|
        controllers_with_readonly_actions << [controller_class, action]
      end
    end

    expect(controllers_with_readonly_actions).to contain_exactly(
      # All the /admin/backups actions that modify data
      [Admin::BackupsController, :readonly],
      [Admin::BackupsController, :create],
      [Admin::BackupsController, :cancel],
      [Admin::BackupsController, :restore],
      [Admin::BackupsController, :rollback],
      [Admin::BackupsController, :destroy],
      [Admin::BackupsController, :email],
      [Admin::BackupsController, :upload_backup_chunk],
      [Admin::BackupsController, :create_multipart],
      [Admin::BackupsController, :abort_multipart],
      [Admin::BackupsController, :complete_multipart],
      [Admin::BackupsController, :batch_presign_multipart_parts],
      # Search uses a POST request but doesn't modify any data
      [CategoriesController, :search],
      # Allows admins to log in (via email) when the site is in readonly mode (cf. https://meta.discourse.org/t/-/89605)
      [SessionController, :email_login],
      [UsersController, :admin_login],
    )
  end

  it "allows only these actions in staff writes only mode" do
    controllers_with_staff_writes_only_actions = []

    ApplicationController.descendants.each do |controller_class|
      controller_class.actions_allowed_in_staff_writes_only_mode&.each do |action|
        controllers_with_staff_writes_only_actions << [controller_class, action]
      end
    end

    expect(controllers_with_staff_writes_only_actions).to contain_exactly(
      # Allows staff to log in using email/username and password
      [SessionController, :create],
      # Allows staff to reset their password (part 1/2)
      [SessionController, :forgot_password],
      # Allows staff to log in via OAuth
      [Users::OmniauthCallbacksController, :complete],
      # Allows staff to log in via email link
      [UsersController, :email_login],
      # Allows staff to reset their password (part 2/2)
      [UsersController, :password_reset_update],
    )
  end
end
