require "sequel/core"

class RodauthMain < Rodauth::Rails::Auth
  configure do
    # List of authentication features that are loaded.
    enable :create_account, :verify_account,
           :login, :logout, :jwt, :close_account,
           :reset_password, :change_password, :json,
           :active_sessions

    # skip_status_checks? { Rails.env.test? }

    db Sequel.postgres(extensions: :activerecord_connection, keep_reference: false)
    convert_token_id_to_integer? false


    email_from "DashClue <noreply@dashclue.com>"
    base_url do
      ENV["FRONTEND_URL"]
    end

    verify_account_email_link do
      "#{base_url}/verify?key=#{token_param_value(verify_account_key_value)}"
    end

    reset_password_email_link do
      "#{base_url}/reset-password?key=#{token_param_value(reset_password_key_value)}"
    end

    # Change prefix of table and foreign key column names from default "account"
    # accounts_table :users
    # verify_account_table :user_verification_keys
    # verify_login_change_table :user_login_change_keys
    # reset_password_table :user_password_reset_keys

    # The secret key used for hashing public-facing tokens for various features.
    # Defaults to Rails `secret_key_base`.

    # Set JWT secret, which is used to cryptographically protect the token.
    jwt_secret { ENV.fetch("JWT_SECRET") }

    # JWTs are stateless, so every token is backed by a row in
    # account_active_session_keys. Logout, password change/reset and account
    # closure delete those rows, which revokes the token server-side.
    session_inactivity_deadline 30.days.to_i
    session_lifetime_deadline 90.days.to_i

    # Accept only JSON requests.
    only_json? true

    # Handle login and password confirmation fields on the client side.
    # require_password_confirmation? false
    # require_login_confirmation? false

    # Use path prefix for all routes.
    # prefix "/auth"

    # Specify the controller used for view rendering, CSRF, and callbacks.
    rails_controller { RodauthController }

    # Make built-in page titles accessible in your views via an instance variable.
    title_instance_variable :@page_title

    # Store account status in an integer column without foreign key constraint.
    account_status_column :status

    # Store password hash in a column instead of a separate table.
    account_password_hash_column :password_hash

    # Set password when creating account instead of when verifying.
    verify_account_set_password? false

    # Change some default param keys.
    login_param "email"
    login_confirm_param "email-confirm"
    # password_confirm_param "confirm_password"

    # Redirect back to originally requested location after authentication.
    # login_return_to_requested_location? true
    # two_factor_auth_return_to_requested_location? true # if using MFA

    # Autologin the user after they have reset their password.
    # reset_password_autologin? true

    # Delete the account record when the user has closed their account.
    # delete_account_on_close? true

    # Reject login/registration requests from a client that already has a session.
    already_logged_in do
      set_response_error_status(400)
      json_response[json_response_error_key] = "You are already logged in"
      return_json_response
    end

    # ==> Emails
    send_email do |email|
      # queue email delivery on the mailer after the transaction commits
      db.after_commit { email.deliver_later }
    end

    # ==> Flash
    # Override default flash messages.
    # create_account_notice_flash "Your account has been created. Please verify your account by visiting the confirmation link sent to your email address."
    # require_login_error_flash "Login is required for accessing this page"
    # login_notice_flash nil

    # ==> Validation
    # Override default validation error messages.
    # no_matching_login_message "user with this email address doesn't exist"
    # already_an_account_with_this_login_message "user with this email address already exists"
    # password_too_short_message { "needs to have at least #{password_minimum_length} characters" }
    # login_does_not_meet_requirements_message { "invalid email#{", #{login_requirement_message}" if login_requirement_message}" }

    # Passwords shorter than 8 characters are considered weak according to OWASP.
    password_minimum_length 8
    # bcrypt has a maximum input length of 72 bytes, truncating any extra bytes.
    password_maximum_bytes 72

    # Custom password complexity requirements (alternative to password_complexity feature).
    # password_meets_requirements? do |password|
    #   super(password) && password_complex_enough?(password)
    # end
    # auth_class_eval do
    #   def password_complex_enough?(password)
    #     return true if password.match?(/\d/) && password.match?(/[^a-zA-Z\d]/)
    #     set_password_requirement_error_message(:password_simple, "requires one number and one special character")
    #     false
    #   end
    # end

    # ==> Hooks
    # Validate custom fields in the create account form.
    # before_create_account do
    #   throw_error_status(422, "name", "must be present") if param("name").empty?
    # end

    # Perform additional actions after the account is created.
    # after_create_account do
    #   Profile.create!(account_id: account_id, name: param("name"))
    # end

    # Sign out every other device when the password changes.
    after_change_password do
      remove_all_active_sessions_except_current
    end

    # Stop billing before the account is closed. Raising here rolls back the
    # close, so a user is never left paying for a closed account.
    before_close_account do
      begin
        AccountClosure.new(Account.find(account_id)).cancel_billing!
      rescue StandardError => e
        Rails.logger.error("Billing cancel failed on close for account=#{account_id}: #{e.class} #{e.message}")
        throw_error_status(422, "password", "We couldn't cancel your subscription. Please try again or contact support.")
      end
    end

    # Remove personal data once the account is closed.
    after_close_account do
      AccountClosure.new(Account.find(account_id)).scrub_data!
    end

    # ==> Deadlines
    # Change default deadlines for some actions.
    # verify_account_grace_period 3.days.to_i
    # reset_password_deadline_interval Hash[hours: 6]
    # verify_login_change_deadline_interval Hash[days: 2]

    prefix "/api/v1"
    login_route "login"
    logout_route "logout"
    create_account_route "register"
  end
end
