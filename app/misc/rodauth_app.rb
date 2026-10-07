class RodauthApp < Rodauth::Rails::App
  # Only parse bodies sent as application/json (Rodauth's default matches any
  # content type containing "json").
  plugin :json_parser, content_type_regexp: %r{\Aapplication/json\b}i

  # primary configuration
  configure RodauthMain

  route do |r|
    # Reject JWTs whose server-side session was revoked or expired
    # (logout, password change/reset, account closure, inactivity).
    rodauth.check_active_session

    r.rodauth # route rodauth requests
  end
end
