module DevCenter

	class Logger

		def initialize(app, options={})
			@app = app
		end

		def call(env)
			begin
				log_page_visit(env)
			rescue Exception => e
				STDOUT.puts e.message
				STDOUT.puts e.backtrace.inspect
			ensure
				return @app.call(env)
			end
		end

		def log_page_visit(env)

			req = Rack::Request.new(env)

			# black list non-GET requests, /assets, /auth, '/heroku-login'
			if(req.get? && req.path =~ /^(?!(\/assets\/|\/auth\/|\/heroku-login\/))/)

				event = { page_title: nil, referrer_query_string: nil, user_heroku_uid: nil, user_email: nil, who: nil }

				event['page_url'] = req.base_url + req.path # Don't want url b/c that includes query_string
				event['page_query_string'] = req.query_string
				event['referrer_url'] = req.referer
				
				event['at'] = Time.now
				event['event_type'] = 'PageVisit'
				event['component'] = 'discussion'
				
				# If they're logged in
				if(req.cookies['user_info'])
					creds = ::HerokuCredentials.decrypt(req.cookies['user_info'])
					event['user_heroku_uid'] = creds.heroku_uid
					event['user_email'] = event['who'] = creds.email
				end

				STDOUT.puts event.to_json
			end			
		end
	end
end

Discourse::Application.configure do
	config.middleware.use DevCenter::Logger
end