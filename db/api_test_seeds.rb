user = User.where(username: "test_user").first_or_create(name: "Test User", email: "test_user@example.com", password: SecureRandom.hex, username: "test_user", approved: true, active: true, admin: true)
UserAuthToken.generate!(user_id: user.id)
ApiKey.create(key: 'test_d7fd0429940', user_id: user.id, created_by_id: user.id)
